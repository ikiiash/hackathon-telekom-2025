export const OpenAIConfig = {
  MODELS: {
    TEXT: `gpt-4.1`,
    IMAGES: `gpt-4o`,
  },
  PROMPTS: {
    AI_DETECTION_FRAME: `
      Determine if this image is AI-generated. 
      Respond ONLY in JSON with fields: ai_generated (true/false), confidence (0-1), reasoning (string).
     `,
  }
};
