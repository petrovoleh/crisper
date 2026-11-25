// Supabase Edge Function: /import-recipe
// Extracts structured culinary recipes from TikTok, Instagram Reels, YouTube, Threads, or Web URLs.
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

  const { url, pantryKeys = [] } = await req.json();
  let metadataSnippet = url;

  try {
    const pageResp = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; CrisperBot/1.0)" },
    });
    if (pageResp.ok) {
      const html = await pageResp.text();
      const ldMatch = html.match(
        /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/i,
      );
      const ogDesc = html.match(
        /<meta[^>]+(?:property=["']og:description["']|name=["']description["'])[^>]+content=["']([^"']+)["']/i,
      );
      metadataSnippet = [
        url,
        ogDesc ? ogDesc[1] : "",
        ldMatch ? ldMatch[1].slice(0, 4000) : "",
      ].join("\n");
    }
  } catch (_) {
    // Fallback to URL context
  }

  const prompt = `Витягни структурований рецепт українською мовою з даних:\n${metadataSnippet}\nЗістав canonicalKey із продуктами користувача: ${pantryKeys.join(", ")}. Поверни JSON за схемою Recipe.`;

  const upstream = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" },
    }),
  });

  const data = await upstream.json();
  return new Response(JSON.stringify(data), {
    status: upstream.status,
    headers: { "Content-Type": "application/json" },
  });
});
