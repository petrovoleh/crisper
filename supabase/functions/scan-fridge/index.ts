// Supabase Edge Function: /scan-fridge
// Secure Gemini 2.5 Flash multimodal proxy for Crisper Android client.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const GEMINI_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "Missing GEMINI_API_KEY" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { imageBase64, locale = "uk" } = await req.json();
  const prompt = `Проаналізуй фото холодильника або чека (мова: ${locale}). Поверни JSON масив продуктів із полями: name, canonicalKey, amountGramsOrPcs, unit, detailNote, category, daysLeft, confidence.`;

  const upstream = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            { text: prompt },
            { inlineData: { mimeType: "image/jpeg", data: imageBase64 } },
          ],
        },
      ],
      generationConfig: { responseMimeType: "application/json" },
    }),
  });

  const data = await upstream.json();
  return new Response(JSON.stringify(data), {
    status: upstream.status,
    headers: { "Content-Type": "application/json" },
  });
});
