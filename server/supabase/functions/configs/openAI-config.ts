export const OpenAIConfig = {
    MODELS: {
        TEXT: `gpt-4.1`,
        IMAGES: `gpt-4o`
    },
    PROMPTS: {
        EXTRACT_TEXT_CONTEXT: `
        Your task is to extract all factual statements or questions from the user's message.

        Rules:
        - Ignore filler, slang, jokes, greetings, personal info, and irrelevant text.
        - Identify every question or factual claim the user is asking about or stating.
        - Convert questions into declarative factual statements if needed.
        - Keep the meaning identical to the original text.
        - Output must be in strict JSON format with an array field "facts":
        {
          "facts": ["fact or question 1", "fact or question 2", ...]
        }
        - If there are no facts or questions, return:
        {
          "facts": []
        }
        
        Here is user text: 
    `,
    }
}