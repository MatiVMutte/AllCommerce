// AllCommerce · Edge Function `analyze-product`
// Recibe { imageBase64, mimeType } de un dueño logueado, verifica que su local
// pueda publicar y le pide a Gemini los datos del producto en JSON estructurado.
// La API key de Gemini vive solo acá (secret GEMINI_API_KEY), nunca en la app.

import { createClient } from "npm:@supabase/supabase-js@2";

const PRIMARY_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";
const FALLBACK_MODEL = "gemini-2.5-flash";
const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
const ALLOWED_MIME = new Set(["image/jpeg", "image/png", "image/webp"]);
const CATEGORIES = [
  "clothing",
  "footwear",
  "accessories",
  "electronics",
  "home",
  "beauty",
  "food",
  "toys",
  "stationery",
  "other",
];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PROMPT = `Sos un asistente para comerciantes minoristas de Argentina que cargan productos a su catálogo online.
Analizá la foto del producto y completá los campos en español rioplatense, con tono comercial y claro.

Reglas:
- title: nombre corto y vendedor del producto (máx. 60 caracteres), con marca/modelo/medida si se ven.
- description: 1 a 3 oraciones con material, uso, color, medidas o contenido visibles. No inventes datos que no se vean.
- category: una sola de la lista permitida; si dudás, "other".
- tags: 3 a 6 palabras clave en minúscula, sin acentos ni signos, útiles para buscar (ej: "vaso", "termico", "acero").
- suggested_price_ars: precio de venta minorista estimado en pesos argentinos, solo si podés estimarlo con razonable confianza; si no, null.
- sku: código o modelo si aparece impreso en el producto o etiqueta; si no, null.
- Si la imagen no muestra un producto reconocible, devolvé title "Producto sin identificar", description vacía, category "other", tags vacío y precio null.`;

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    title: { type: "STRING" },
    description: { type: "STRING" },
    category: { type: "STRING", enum: CATEGORIES },
    tags: { type: "ARRAY", items: { type: "STRING" } },
    suggested_price_ars: { type: "NUMBER", nullable: true },
    sku: { type: "STRING", nullable: true },
  },
  required: ["title", "description", "category", "tags"],
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function error(status: number, code: string, message: string): Response {
  return json(status, { error: { code, message } });
}

async function callGemini(
  model: string,
  apiKey: string,
  imageBase64: string,
  mimeType: string,
): Promise<Response> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
    body: JSON.stringify({
      contents: [{
        role: "user",
        parts: [
          { text: PROMPT },
          { inline_data: { mime_type: mimeType, data: imageBase64 } },
        ],
      }],
      generationConfig: {
        temperature: 0.2,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
      },
    }),
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return error(405, "METHOD_NOT_ALLOWED", "Usá POST");
  }

  // 1. Usuario logueado --------------------------------------------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return error(401, "AUTH_REQUIRED", "Iniciá sesión para continuar");
  }
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: claims, error: claimsError } = await supabase.auth.getClaims(
    authHeader.slice("Bearer ".length),
  );
  const userId = claims?.claims?.sub;
  if (claimsError || !userId) {
    return error(401, "AUTH_REQUIRED", "Sesión inválida o vencida");
  }

  // 2. Es dueño y su local puede publicar (RLS: solo ve su propia fila) -------
  const { data: profile } = await supabase
    .from("users")
    .select("role, tenant_id")
    .eq("id", userId)
    .maybeSingle();
  if (!profile || profile.role !== "owner" || !profile.tenant_id) {
    return error(403, "OWNER_REQUIRED", "Solo los dueños pueden usar la IA");
  }
  const { data: tenant } = await supabase
    .from("tenants")
    .select("is_active, plan_expires_at")
    .eq("id", profile.tenant_id)
    .maybeSingle();
  const canPublish = tenant?.is_active === true &&
    new Date(tenant.plan_expires_at).getTime() > Date.now();
  if (!canPublish) {
    return error(403, "PLAN_EXPIRED", "Tu plan está vencido o inactivo");
  }

  // 3. Validar imagen -----------------------------------------------------------
  let body: { imageBase64?: string; mimeType?: string };
  try {
    body = await req.json();
  } catch {
    return error(400, "INVALID_BODY", "Body inválido");
  }
  const imageBase64 = body.imageBase64 ?? "";
  const mimeType = body.mimeType ?? "";
  if (!imageBase64 || !ALLOWED_MIME.has(mimeType)) {
    return error(400, "INVALID_IMAGE", "Enviá una imagen JPEG, PNG o WebP");
  }
  if (imageBase64.length * 0.75 > MAX_IMAGE_BYTES) {
    return error(413, "IMAGE_TOO_LARGE", "La imagen supera los 2 MB");
  }

  // 4. Cuota de análisis del mes (reserva; se devuelve si la IA falla) ---------
  const { data: quota, error: quotaErr } = await supabase.rpc(
    "consume_ai_analysis",
  );
  if (quotaErr) {
    if (quotaErr.message.includes("AI_LIMIT_REACHED")) {
      return error(
        403,
        "AI_LIMIT_REACHED",
        "Llegaste al límite de análisis con IA de tu plan este mes",
      );
    }
    if (quotaErr.message.includes("PLAN_EXPIRED")) {
      return error(403, "PLAN_EXPIRED", "Tu plan está vencido o inactivo");
    }
    if (quotaErr.message.includes("OWNER_REQUIRED")) {
      return error(403, "OWNER_REQUIRED", "Solo los dueños pueden usar la IA");
    }
    console.error("quota error", quotaErr);
    return error(500, "QUOTA_ERROR", "No se pudo verificar tu cuota de IA");
  }

  // Si la IA falla después de reservar, el análisis no se cobra.
  async function refundAndError(
    status: number,
    code: string,
    message: string,
  ): Promise<Response> {
    const { error: refundErr } = await supabase.rpc("refund_ai_analysis");
    if (refundErr) console.error("refund error", refundErr);
    return error(status, code, message);
  }

  // 5. Gemini con fallback de modelo --------------------------------------------
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return refundAndError(500, "AI_NOT_CONFIGURED", "Falta configurar la IA");
  }

  let model = PRIMARY_MODEL;
  let res = await callGemini(model, apiKey, imageBase64, mimeType);
  if ((res.status === 429 || res.status === 404) && model !== FALLBACK_MODEL) {
    model = FALLBACK_MODEL;
    res = await callGemini(model, apiKey, imageBase64, mimeType);
  }
  if (res.status === 429) {
    return refundAndError(429, "AI_RATE_LIMITED", "La IA está ocupada, probá en un minuto");
  }
  if (!res.ok) {
    console.error("gemini error", model, res.status, await res.text());
    return refundAndError(502, "AI_UNAVAILABLE", "La IA no respondió, cargá los datos a mano");
  }

  const payload = await res.json();
  const text: string | undefined =
    payload?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    return refundAndError(502, "AI_EMPTY", "La IA no devolvió datos");
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text);
  } catch {
    return refundAndError(502, "AI_INVALID_JSON", "La IA devolvió un formato inesperado");
  }

  // 6. Normalizar la salida (nunca confiar ciegamente en el modelo) -------------
  const category = typeof parsed.category === "string" &&
      CATEGORIES.includes(parsed.category)
    ? parsed.category
    : "other";
  const tags = Array.isArray(parsed.tags)
    ? parsed.tags.filter((t): t is string => typeof t === "string")
      .map((t) => t.trim().toLowerCase()).filter(Boolean).slice(0, 8)
    : [];
  const price = typeof parsed.suggested_price_ars === "number" &&
      parsed.suggested_price_ars > 0
    ? Math.round(parsed.suggested_price_ars)
    : null;

  return json(200, {
    model,
    quota: { used: quota?.used ?? 0, limit: quota?.limit ?? null },
    product: {
      title: String(parsed.title ?? "").trim().slice(0, 120),
      description: String(parsed.description ?? "").trim().slice(0, 1000),
      category,
      tags,
      suggested_price_ars: price,
      sku: typeof parsed.sku === "string" && parsed.sku.trim()
        ? parsed.sku.trim().slice(0, 60)
        : null,
    },
  });
});
