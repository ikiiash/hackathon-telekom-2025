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

        const { text, image_url } = await req.json().catch(() => ({}));

        if (!text && !image_url) {
            return new Response(
                JSON.stringify({ error: "At least 'text' or 'image_url' is required" }), 
                { status: 400, headers: { "Content-Type": "application/json" } }
            );
        }

        const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY");
        if (!OPENAI_KEY) {
            return new Response(JSON.stringify({ error: "OPENAI_API_KEY missing" }), {
                status: 500,
                headers: { "Content-Type": "application/json" },
            });
        }

        const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
        const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

        let imageAnalysis = null;
        let textFacts = null;
        let factCheckResults = null;

        // 1. Analyze image if present
        if (image_url) {
            try {
                const imageResponse = await fetch(`${SUPABASE_URL}/functions/v1/image-check`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                    },
                    body: JSON.stringify({ image_url }),
                });

                if (imageResponse.ok) {
                    imageAnalysis = await imageResponse.json();
                }
            } catch (error) {
                console.error("Image check failed:", error);
            }
        }

        // 2. Extract facts from text if present
        if (text && text.trim()) {
            try {
                const textValidationResponse = await fetch(
                    `${SUPABASE_URL}/functions/v1/text-validation`,
                    {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                        },
                        body: JSON.stringify({ text }),
                    }
                );

                if (textValidationResponse.ok) {
                    textFacts = await textValidationResponse.json();
                }
            } catch (error) {
                console.error("Text validation failed:", error);
            }
        }

        // 3. Fact-check extracted claims if any
        if (textFacts && textFacts.facts && textFacts.facts.length > 0) {
            try {
                const factCheckResponse = await fetch(
                    `${SUPABASE_URL}/functions/v1/fact-check`,
                    {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                        },
                        body: JSON.stringify({ 
                            text: text || "",
                            facts: textFacts.facts 
                        }),
                    }
                );

                if (factCheckResponse.ok) {
                    factCheckResults = await factCheckResponse.json();
                }
            } catch (error) {
                console.error("Fact check failed:", error);
            }
        }

        // 4. Generate final response using OpenAI
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

        const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${OPENAI_KEY}`,
            },
            body: JSON.stringify({
                model: OpenAIConfig.MODELS.TEXT,
                messages: [
                    { role: "system", content: "You are TrustAI, a helpful fact-checking assistant. Provide clear, concise responses." },
                    { role: "user", content: finalPrompt }
                ],
                temperature: 0.7,
                max_tokens: 800,
            }),
        });

        if (!openaiResponse.ok) {
            return new Response(
                JSON.stringify({
                    error: "Failed to generate final response",
                    status: openaiResponse.status,
                }),
                { status: 500, headers: { "Content-Type": "application/json" } }
            );
        }

        const ai = await openaiResponse.json();
        const finalResponse = ai.choices?.[0]?.message?.content;

        if (!finalResponse) {
            return new Response(
                JSON.stringify({ error: "OpenAI returned empty response" }),
                { status: 500, headers: { "Content-Type": "application/json" } }
            );
        }

        // Return the final formatted response
        return new Response(
            JSON.stringify({
                response: finalResponse,
                // Include raw data for debugging if needed
                debug: {
                    image_analysis: imageAnalysis,
                    text_facts: textFacts,
                    fact_check: factCheckResults,
                },
            }),
            { status: 200, headers: { "Content-Type": "application/json" } }
        );

    } catch (err) {
        console.error("Error in analyze-content:", err);
        return new Response(
            JSON.stringify({ 
                error: "Internal error", 
                details: err.message 
            }),
            { status: 500, headers: { "Content-Type": "application/json" } }
        );
    }
});
