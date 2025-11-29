import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { OpenAIConfig } from "../configs/openAI-config.ts";

serve(async (req) => {
    try {
        if (req.method !== "POST") {
            return new Response(JSON.stringify({ error: "Only POST allowed" }), {
                status: 405,
                headers: { "Content-Type": "application/json" },
            });
        }

        const { text } = await req.json().catch(() => ({}));

        if (!text || typeof text !== "string") {
            return new Response(JSON.stringify({ error: "Field 'text' is required" }), {
                status: 400,
                headers: { "Content-Type": "application/json" },
            });
        }

        const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY");
        if (!OPENAI_KEY) {
            return new Response(JSON.stringify({ error: "OPENAI_API_KEY missing" }), {
                status: 500,
                headers: { "Content-Type": "application/json" },
            });
        }

        const prompt = `${OpenAIConfig.PROMPTS.EXTRACT_TEXT_CONTEXT} ${text}.`;

        const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${OPENAI_KEY}`,
            },
            body: JSON.stringify({
                model: OpenAIConfig.MODELS.TEXT,
                messages: [{ role: "user", content: prompt }],
                temperature: 0,
            }),
        });

        if (!openaiResponse.ok) {
            return new Response(
                JSON.stringify({
                    error: "OpenAI request failed",
                    status: openaiResponse.status,
                    detail: await openaiResponse.text(),
                }),
                { status: 500, headers: { "Content-Type": "application/json" } }
            );
        }

        const ai = await openaiResponse.json();
        const raw = ai.choices?.[0]?.message?.content;

        if (!raw) {
            return new Response(
                JSON.stringify({
                    error: "OpenAI returned empty response",
                }),
                { status: 500, headers: { "Content-Type": "application/json" } }
            );
        }

        let parsed;
        try {
            parsed = JSON.parse(raw);
        } catch {
            parsed = { context: raw };
        }

        return new Response(JSON.stringify(parsed), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });

    } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
        });
    }
});
