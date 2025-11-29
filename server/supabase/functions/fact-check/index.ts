// supabase/functions/fact-check-advanced/index.ts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { OpenAIConfig } from "../configs/openAI-config.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SEARCH_API_KEY = Deno.env.get("SEARCH_API_KEY");
const SEARCH_API_URL = Deno.env.get("SEARCH_API_URL");      

if (!OPENAI_API_KEY) {
  console.error("OPENAI_API_KEY is missing!");
}

// --------------------
// OpenAI helper
// --------------------
async function callOpenAIChat(body: unknown): Promise<string> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error("OpenAI error:", err);
    throw new Error("OpenAI API error: " + err);
  }

  const data = await res.json();
  const content = data.choices[0].message.content;
  return typeof content === "string" ? content : JSON.stringify(content);
}

// --------------------
// 1) CLAIM EXTRACTION
// --------------------
async function extractClaims(text: string) {
  const raw = await callOpenAIChat({
    model: "gpt-4.1",
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content: `
Extract only factual claims (who/what/when/where).

Return STRICT JSON:
{
  "claims": [
    { "id": "c1", "text": "..." },
    { "id": "c2", "text": "..." }
  ]
}
If there are no factual claims, return an empty list.
`.trim(),
      },
      { role: "user", content: text },
    ],
  });

  const parsed = JSON.parse(raw);
  return parsed.claims ?? [];
}

// --------------------
// 2) WIKIPEDIA
// --------------------
async function fetchWikipediaSnippet(query: string): Promise<string> {
  try {
    // Search
    const url = new URL("https://en.wikipedia.org/w/api.php");
    url.searchParams.set("action", "query");
    url.searchParams.set("list", "search");
    url.searchParams.set("srsearch", query);
    url.searchParams.set("format", "json");
    url.searchParams.set("utf8", "1");
    url.searchParams.set("srlimit", "1");

    const res = await fetch(url.toString());
    if (!res.ok) return "";
    const data = await res.json();

    const first = data?.query?.search?.[0];
    if (!first) return "";

    // Extract
    const pageUrl = new URL("https://en.wikipedia.org/w/api.php");
    pageUrl.searchParams.set("action", "query");
    pageUrl.searchParams.set("prop", "extracts");
    pageUrl.searchParams.set("explaintext", "1");
    pageUrl.searchParams.set("format", "json");
    pageUrl.searchParams.set("pageids", String(first.pageid));

    const res2 = await fetch(pageUrl.toString());
    if (!res2.ok) return "";
    const data2 = await res2.json();

    const page = data2.query.pages[String(first.pageid)];
    const extract = page.extract ?? "";

    return extract.slice(0, 1200);
  } catch {
    return "";
  }
}

// --------------------
// 3) SERPAPI (optional)
// --------------------
async function fetchSearchSnippets(query: string): Promise<string[]> {
  if (!SEARCH_API_KEY || !SEARCH_API_URL) return [];

  try {
    const url = new URL(SEARCH_API_URL);
    url.searchParams.set("api_key", SEARCH_API_KEY);
    url.searchParams.set("engine", "google");
    url.searchParams.set("q", query);
    url.searchParams.set("num", "5");

    const res = await fetch(url.toString());
    if (!res.ok) return [];

    const data = await res.json();
    const organic = data.organic_results ?? [];

    return organic
      .map((r: any) => r.snippet ?? "")
      .filter((x: string) => x.trim().length > 0)
      .slice(0, 3);
  } catch {
    return [];
  }
}

// --------------------
// MAIN
// --------------------
serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Only POST allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } },
    );
  }

  try {
    const body = await req.json() as { text?: string; facts?: string[] };

    const text = body.text ?? "";
    const facts = Array.isArray(body.facts) ? body.facts : [];

    if (!text && facts.length === 0) {
      return new Response(
        JSON.stringify({
          error: "You must provide either 'text' (string) or 'facts' (array of strings).",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // 1) Build claims: either from facts[] or via extractClaims(text)
    let claims: { id: string; text: string }[] = [];

    if (facts.length > 0) {
      // Use provided facts as claims
      claims = facts.map((fact, idx) => ({
        id: `f${idx + 1}`,
        text: String(fact),
      }));
    } else {
      // Fallback: extract claims from text using the model
      if (!text || typeof text !== "string" || text.trim().length === 0) {
        return new Response(
          JSON.stringify({
            error: "'text' must be a non-empty string when 'facts' are not provided.",
          }),
          { status: 400, headers: { "Content-Type": "application/json" } },
        );
      }
      claims = await extractClaims(text);
    }

    // 2) Gather evidence for each claim
    const evidence = await Promise.all(
      claims.map(async (c) => {
        const wiki = await fetchWikipediaSnippet(c.text);
        const search = await fetchSearchSnippets(c.text);
        return {
          id: c.id,
          text: c.text,
          wikipedia: wiki,
          web_snippets: search,
        };
      }),
    );

    // 3) Ask OpenAI to do the advanced fact-checking
    const rawAnalysis = await callOpenAIChat({
      model: OpenAIConfig.MODELS.TEXT,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: OpenAIConfig.PROMPTS.FACT_CHECKING_SYSTEM.trim(),
        },
        {
          role: "user",
          content: JSON.stringify({
            original_text: text,
            claims,
            evidence,
          }),
        },
      ],
    });

    const parsed = JSON.parse(rawAnalysis);

    return new Response(
      JSON.stringify({
        original_text: text,
        claims: parsed.claims ?? [],
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Error in fact-check-advanced:", err);
    return new Response(
      JSON.stringify({
        error: "Internal error",
        details: String(err),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});

