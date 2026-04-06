const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const geminiApiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
const analysisModel = "gemini-2.5-flash";
const imageModel = "imagen-4.0-generate-001";

type StructuredAnalyzeResult = {
  dishName: string;
  subtitle: string;
  usedIngredients: string[];
  pantryAssumptions: string[];
  whyItWorks: string;
  whyHealthy: string;
  whyDelicious: string;
  timeMinutes: number;
  steps: string[];
  finalResultDescription: string;
  detectedIngredients: Array<{
    name: string;
    confidence: number;
    note: string | null;
  }>;
  uncertainIngredients: Array<{
    name: string;
    confidence: number;
    note: string | null;
  }>;
  modelSummary: string;
};

const analyzePrompt = `
You are the recipe engine for Folding Fridge.

You receive one photo of a user's refrigerator.
Your job:
1. Identify the visible ingredients conservatively.
2. Choose one best dish only.
3. Write a recipe that is realistic, healthy, delicious, and achievable in a normal home kitchen.
4. Never invent complicated restaurant technique.
5. If an ingredient is uncertain, put it in uncertainIngredients instead of detectedIngredients.

Return JSON only.
`.trim();

const responseSchema = {
  type: "object",
  properties: {
    dishName: { type: "string" },
    subtitle: { type: "string" },
    usedIngredients: {
      type: "array",
      items: { type: "string" },
    },
    pantryAssumptions: {
      type: "array",
      items: { type: "string" },
    },
    whyItWorks: { type: "string" },
    whyHealthy: { type: "string" },
    whyDelicious: { type: "string" },
    timeMinutes: { type: "integer" },
    steps: {
      type: "array",
      items: { type: "string" },
    },
    finalResultDescription: { type: "string" },
    detectedIngredients: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          confidence: { type: "number" },
          note: { type: ["string", "null"] },
        },
        required: ["name", "confidence", "note"],
      },
    },
    uncertainIngredients: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          confidence: { type: "number" },
          note: { type: ["string", "null"] },
        },
        required: ["name", "confidence", "note"],
      },
    },
    modelSummary: { type: "string" },
  },
  required: [
    "dishName",
    "subtitle",
    "usedIngredients",
    "pantryAssumptions",
    "whyItWorks",
    "whyHealthy",
    "whyDelicious",
    "timeMinutes",
    "steps",
    "finalResultDescription",
    "detectedIngredients",
    "uncertainIngredients",
    "modelSummary",
  ],
};

function jsonResponse(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function extractGeminiText(payload: any): string {
  const parts = payload?.candidates?.[0]?.content?.parts ?? [];
  const textPart = parts.find((part: any) => typeof part?.text === "string");
  return textPart?.text ?? "";
}

function extractImagenBase64(payload: any): string | null {
  return (
    payload?.generatedImages?.[0]?.image?.imageBytes ??
    payload?.predictions?.[0]?.bytesBase64Encoded ??
    payload?.predictions?.[0]?.image?.imageBytes ??
    payload?.images?.[0]?.bytesBase64Encoded ??
    null
  );
}

async function analyzeImage(imageBase64: string): Promise<StructuredAnalyzeResult> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${analysisModel}:generateContent?key=${geminiApiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: analyzePrompt },
              {
                inlineData: {
                  mimeType: "image/jpeg",
                  data: imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseJsonSchema: responseSchema,
        },
      }),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Gemini analyze failed: ${text}`);
  }

  const payload = await response.json();
  const text = extractGeminiText(payload);

  if (!text) {
    throw new Error("Gemini analyze returned no JSON text.");
  }

  const parsed = JSON.parse(text) as StructuredAnalyzeResult;
  return parsed;
}

function buildImagePrompt(result: StructuredAnalyzeResult): string {
  return [
    `Create a realistic plated food image of ${result.dishName}.`,
    `The dish uses: ${result.usedIngredients.join(", ")}.`,
    "Style: healthy home cooking, natural daylight, editorial but believable, clean plate, minimal styling.",
    "Do not add ingredients that are not already in the recipe.",
    "Do not make it look like restaurant luxury plating.",
    "No text, no hands, no packaging, no cutlery dominating the frame.",
  ].join(" ");
}

async function generateDishImage(result: StructuredAnalyzeResult): Promise<string | null> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${imageModel}:predict`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiApiKey,
      },
      body: JSON.stringify({
        instances: [
          {
            prompt: buildImagePrompt(result),
          },
        ],
        parameters: {
          sampleCount: 1,
          aspectRatio: "4:3",
          personGeneration: "dont_allow",
        },
      }),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Gemini image generation failed: ${text}`);
  }

  const payload = await response.json();
  return extractImagenBase64(payload);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!geminiApiKey) {
    return jsonResponse({ error: "GEMINI_API_KEY is missing from Edge Function secrets." }, 500);
  }

  try {
    const body = await request.json();
    const imageBase64 = body?.imageBase64;

    if (!imageBase64 || typeof imageBase64 !== "string") {
      return jsonResponse({ error: "imageBase64 is required" }, 400);
    }

    const analysis = await analyzeImage(imageBase64);

    let generatedImageData: string | null = null;
    try {
      generatedImageData = await generateDishImage(analysis);
    } catch (imageError) {
      console.error("Image generation failed", imageError);
    }

    const payload = {
      detectedIngredients: analysis.detectedIngredients.map((ingredient) => ({
        id: crypto.randomUUID(),
        name: ingredient.name,
        confidence: ingredient.confidence,
        note: ingredient.note,
      })),
      uncertainIngredients: analysis.uncertainIngredients.map((ingredient) => ({
        id: crypto.randomUUID(),
        name: ingredient.name,
        confidence: ingredient.confidence,
        note: ingredient.note,
      })),
      recipes: [
        {
          id: crypto.randomUUID(),
          title: analysis.dishName,
          subtitle: analysis.subtitle,
          generatedImageData,
          usedIngredients: analysis.usedIngredients,
          pantryAssumptions: analysis.pantryAssumptions,
          whyItWorks: analysis.whyItWorks,
          whyHealthy: analysis.whyHealthy,
          whyDelicious: analysis.whyDelicious,
          timeMinutes: analysis.timeMinutes,
          steps: analysis.steps,
          finalResultDescription: analysis.finalResultDescription,
        },
      ],
      modelSummary: analysis.modelSummary,
    };

    return jsonResponse(payload, 200);
  } catch (error) {
    return jsonResponse(
      {
        error: "Analyze failed",
        detail: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});
