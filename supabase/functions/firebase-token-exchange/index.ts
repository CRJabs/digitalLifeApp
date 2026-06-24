import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createRemoteJWKSet, jwtVerify } from "https://deno.land/x/jose@v4.14.4/index.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Fetch Google's public JWK set for Firebase token validation
const JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

const FIREBASE_PROJECT_ID = "digital-life-app-f82f9";
const SUPABASE_JWT_SECRET = Deno.env.get("JWT_SECRET")!;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { firebaseToken } = await req.json();
    if (!firebaseToken) {
      throw new Error("Missing firebaseToken in request body");
    }

    // 1. Verify the Firebase ID Token against Google's certificates
    const { payload } = await jwtVerify(firebaseToken, JWKS, {
      issuer: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
      audience: FIREBASE_PROJECT_ID,
    });

    const uid = payload.sub; // Firebase UID
    const email = (payload.email as string) || "";

    if (!uid) {
      throw new Error("Invalid token: sub claim is missing");
    }

    // 2. Generate Supabase JWT signed with Supabase's JWT_SECRET
    const keyBuf = new TextEncoder().encode(SUPABASE_JWT_SECRET);
    const cryptoKey = await crypto.subtle.importKey(
      "raw", keyBuf, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
    );

    const exp = getNumericDate(60 * 60 * 24 * 7); // 1 week
    const supabasePayload = {
      role: "authenticated",
      iss: "supabase",
      sub: uid, // Becomes auth.uid() in Supabase RLS!
      email: email,
      exp,
    };

    const supabaseToken = await create(
      { alg: "HS256", typ: "JWT" },
      supabasePayload,
      cryptoKey
    );

    return new Response(
      JSON.stringify({ 
        access_token: supabaseToken,
        expires_at: exp
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );

  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ error: err.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
