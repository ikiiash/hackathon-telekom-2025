import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { OpenAIConfig } from "../configs/openAI-config.ts";

const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!OPENAI_KEY || !SUPABASE_URL || !SUPABASE_ANON_KEY || !SERVICE_ROLE_KEY) {
    console.error("Missing required environment variables");
}

serve(async (req) => {
    try {
        if (req.method !== "POST") {
            return json({ error: "Only POST allowed" }, 405);
        }

        const { text, image_url, chat_id } = await req.json().catch(() => ({}));

        if (!text && !image_url) {
            return json(
                { error: "At least 'text' or 'image_url' is required" },
                400,
            );
        }

        // -------- 1. JWT / user_id --------
        const authHeader = req.headers.get("Authorization");
        if (!authHeader?.startsWith("Bearer ")) {
            return json({ error: "Missing user token" }, 401);
        }
        const jwt = authHeader.split(" ")[1];

        // простий парс payload з JWT (supabase кладе id в sub)
        let userId: string | null = null;
        try {
            const payloadJson = atob(jwt.split(".")[1]);
            const payload = JSON.parse(payloadJson);
            userId = payload.sub as string;
        } catch (e) {
            console.error("JWT parse error:", e);
            return json({ error: "Invalid user token" }, 401);
        }

        // -------- 2. PIPELINE: image / text / fact-check --------
        let imageAnalysis: any = null;
        let textFacts: any = null;
        let factCheckResults: any = null;

        // 2.1 image-check
        if (image_url) {
            try {
                const imageResp = await fetch(
                    `${SUPABASE_URL}/functions/v1/image-check`,
                    {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            Authorization: `Bearer ${SERVICE_ROLE_KEY}`, // сервіс-роль для внутрішньої функції
                        },
                        body: JSON.stringify({ image_url }),
                    },
                );
                if (imageResp.ok) imageAnalysis = await imageResp.json();
                else console.error("image-check:", await imageResp.text());
            } catch (e) {
                console.error("Image check failed:", e);
            }
        }

        // 2.2 text-validation
        if (text?.trim()) {
            try {
                const textResp = await fetch(
                    `${SUPABASE_URL}/functions/v1/text-validation`,
                    {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
                        },
                        body: JSON.stringify({ text }),
                    },
                );
                if (textResp.ok) textFacts = await textResp.json();
                else console.error("text-validation:", await textResp.text());
            } catch (e) {
                console.error("Text validation failed:", e);
            }
        }

        // 2.3 fact-check
        if (textFacts?.facts?.length) {
            try {
                const factCheckResp = await fetch(
                    `${SUPABASE_URL}/functions/v1/fact-check`,
                    {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
                        },
                        body: JSON.stringify({
                            text: text || "",
                            facts: textFacts.facts,
                        }),
                    },
                );
                if (factCheckResp.ok) factCheckResults = await factCheckResp.json();
                else console.error("fact-check:", await factCheckResp.text());
            } catch (e) {
                console.error("Fact check failed:", e);
            }
        }

        // -------- 3. Відповідь через OpenAI --------
        const analysisContext = {
            user_text: text || "(no text provided)",
            user_image: image_url ? "User provided an image" : "No image provided",
            image_analysis: imageAnalysis,
            extracted_facts: textFacts,
            fact_check_results: factCheckResults,
        };

        const finalPrompt = `${OpenAIConfig.PROMPTS.FINAL_RESPONSE_GENERATION}


Analysis Data:
${JSON.stringify(analysisContext, null, 2)}`;

        const openaiResp = await fetch(
            "https://api.openai.com/v1/chat/completions",
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${OPENAI_KEY}`,
                },
                body: JSON.stringify({
                    model: OpenAIConfig.MODELS.TEXT,
                    messages: [
                        {
                            role: "system",
                            content:
                                "You are TrustAI, a helpful fact-checking assistant.",
                        },
                        {
                            role: "user",
                            content: finalPrompt,
                        },
                    ],
                    temperature: 0.7,
                    max_tokens: 800,
                }),
            },
        );

        if (!openaiResp.ok) {
            console.error("OpenAI error:", await openaiResp.text());
            return json(
                { error: "Failed to generate final response", status: openaiResp.status },
                500,
            );
        }

        const ai = await openaiResp.json();
        const finalResponse = ai.choices?.[0]?.message?.content as string | undefined;

        if (!finalResponse) {
            return json({ error: "OpenAI returned empty response" }, 500);
        }

        // -------- 4. chat_id (історія чатів) --------
        let currentChatId: string | undefined = chat_id;

        // Якщо chat_id не передали → створюємо новий чат
        if (!currentChatId) {
            const chatResp = await fetch(`${SUPABASE_URL}/rest/v1/chat`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    apikey: SUPABASE_ANON_KEY,
                    Authorization: `Bearer ${jwt}`, // JWT користувача → RLS
                    Prefer: "return=representation",
                },
                body: JSON.stringify({
                    user_id: userId,
                    title: text ? text.slice(0, 60) : "New chat",
                    created_at: new Date().toISOString(),
                }),
            });

            if (!chatResp.ok) {
                console.error("Create chat error:", await chatResp.text());
                return json({ error: "Failed to create chat" }, 500);
            }

            const chatData = await chatResp.json();
            currentChatId = chatData?.[0]?.id;
        }

        if (!currentChatId) {
            return json({ error: "Could not determine chat_id" }, 500);
        }

        // -------- 5. Збереження повідомлень --------

        // 5.1 user message
        await fetch(`${SUPABASE_URL}/rest/v1/message`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                apikey: SUPABASE_ANON_KEY,
                Authorization: `Bearer ${jwt}`,
                Prefer: "return=representation",
            },
            body: JSON.stringify({
                chat_id: currentChatId,
                role: "user",
                content: text || null,
                image_url: image_url || null,
                debug: null,
            }),
        });

        // 5.2 assistant message
        await fetch(`${SUPABASE_URL}/rest/v1/message`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                apikey: SUPABASE_ANON_KEY,
                Authorization: `Bearer ${jwt}`,
                Prefer: "return=representation",
            },
            body: JSON.stringify({
                chat_id: currentChatId,
                role: "assistant",
                content: finalResponse,
                image_url: null,
                debug: {
                    image_analysis: imageAnalysis,
                    text_facts: textFacts,
                    fact_check: factCheckResults,
                },
            }),
        });

        return json(
            {
                chat_id: currentChatId,
                response: finalResponse,
            },
            200,
        );
    } catch (err: any) {
        console.error("Error in analyze-content:", err);
        return json(
            {
                error: "Internal error",
                details: String(err?.message ?? err),
            },
            500,
        );
    }
});

function json(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}
