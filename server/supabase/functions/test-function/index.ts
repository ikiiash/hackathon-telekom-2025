import { serve } from "https://deno.land/std/http/server.ts";

serve(async (req) => {
  const body = await req.json().catch(() => null);

  return new Response(
    JSON.stringify({
      message: "Функция работает!",
      input: body,
    }),
    {
      headers: { "Content-Type": "application/json" },
    }
  );
});
