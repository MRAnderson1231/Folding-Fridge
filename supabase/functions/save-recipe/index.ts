import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }

  try {
    const body = await request.json();
    const recipe = body?.recipe;

    if (!recipe) {
      return new Response(JSON.stringify({ error: "recipe is required" }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      });
    }

    const payload = {
      id: recipe.id,
      recipe: recipe.recipe,
      analysis_payload: recipe.analysisPayload ?? null,
      image_data: recipe.imageData ?? null,
      saved_at: recipe.savedAt ?? new Date().toISOString(),
    };

    const { error } = await admin.from("saved_recipes").upsert(payload);

    if (error) {
      throw error;
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: "Save failed",
        detail: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});
