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

        const { image_url } = await req.json().catch(() => ({}));

        if (!image_url || typeof image_url !== "string") {
            return new Response(JSON.stringify({ error: "Field 'image_url' is required" }), {
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

        // Download image to analyze EXIF metadata
        let exifData = null;
        try {
            const imageResponse = await fetch(image_url);
            if (imageResponse.ok) {
                const imageBuffer = await imageResponse.arrayBuffer();
                exifData = await extractExifData(imageBuffer);
            }
        } catch (error) {
            console.error("EXIF extraction failed:", error);
        }

        // Prepare EXIF context for OpenAI
        const exifContext = exifData ? `\n\nEXIF Metadata Analysis:\n- Has EXIF: ${exifData.has_exif}\n- Details: ${exifData.message}${exifData.segment_size ? `\n- Segment size: ${exifData.segment_size} bytes` : ''}${exifData.error ? `\n- Error: ${exifData.error}` : ''}` : '';

        // Use GPT-4 Vision to analyze the image with EXIF context
        const prompt = OpenAIConfig.PROMPTS.IMAGE_AI_DETECTION + exifContext;

        const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${OPENAI_KEY}`,
            },
            body: JSON.stringify({
                model: OpenAIConfig.MODELS.IMAGES,
                messages: [
                    {
                        role: "user",
                        content: [
                            { type: "text", text: prompt },
                            { type: "image_url", image_url: { url: image_url } }
                        ]
                    }
                ],
                temperature: 0,
                max_tokens: 300,
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
                JSON.stringify({ error: "OpenAI returned empty response" }),
                { status: 500, headers: { "Content-Type": "application/json" } }
            );
        }

        let parsed;
        try {
            parsed = JSON.parse(raw);
        } catch {
            parsed = { 
                description: "Unable to parse response",
                is_ai_generated: null,
                confidence: 0,
                reasoning: raw 
            };
        }

        // Add EXIF metadata analysis to the response
        const response = {
            ...parsed,
            exif: exifData,
        };

        return new Response(JSON.stringify(response), {
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

// Extract EXIF metadata from image buffer
async function extractExifData(buffer: ArrayBuffer): Promise<any> {
    try {
        const bytes = new Uint8Array(buffer);
        
        // Check for JPEG marker (0xFFD8)
        if (bytes[0] !== 0xFF || bytes[1] !== 0xD8) {
            return { has_exif: false, message: "Not a JPEG image" };
        }

        // Look for EXIF marker (0xFFE1)
        let offset = 2;
        while (offset < bytes.length - 1) {
            if (bytes[offset] === 0xFF && bytes[offset + 1] === 0xE1) {
                // Found APP1 marker (EXIF)
                const segmentLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
                
                // Check for "Exif" string
                if (bytes[offset + 4] === 0x45 && bytes[offset + 5] === 0x78 && 
                    bytes[offset + 6] === 0x69 && bytes[offset + 7] === 0x66) {
                    
                    return {
                        has_exif: true,
                        segment_size: segmentLength,
                        message: "EXIF data present (detailed extraction requires EXIF parser library)"
                    };
                }
            }
            
            // Skip to next marker
            if (bytes[offset] === 0xFF) {
                const markerLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
                offset += 2 + markerLength;
            } else {
                offset++;
            }
            
            // Prevent infinite loop
            if (offset > 65536) break;
        }

        return { 
            has_exif: false, 
            message: "No EXIF data found - possible indicators: screenshot, AI-generated, or metadata stripped" 
        };

    } catch (error) {
        return { 
            has_exif: false, 
            error: error.message,
            message: "Failed to analyze EXIF data" 
        };
    }
}
