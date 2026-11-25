// Supabase Edge Function: /suggest-recipes
// Generates personalized Zero-Waste recipes from the user's current fridge inventory & expiring items.
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

  const {
    pantry = [],
    dietMode = "omnivore",
    allergies = [],
    householdSize = 2,
    mealTime = "dinner",
  } = await req.json();

  const prompt = `Ти — AI-сушеф Crisper. Створи 3 реалістичні домашні Zero-Waste рецепти українською мовою на основі наявних продуктів (пріоритет тим, у яких найменше днів свіжості).
Дієта: ${dietMode}. Алергії: ${allergies.join(", ") || "немає"}. Порцій: ${householdSize}. Час прийому їжі: ${mealTime}.
Продукти у холодильнику: ${JSON.stringify(pantry)}
Для КОЖНОГО кроку обов'язково вкажи timerSeconds > 0 (ніколи не став 0) та isTimerEstimated (true якщо час орієнтовний).
Поверни JSON масив об'єктів Recipe.`;

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
