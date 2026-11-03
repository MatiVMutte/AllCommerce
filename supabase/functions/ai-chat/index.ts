// AllCommerce · Edge Function `ai-chat`
// Chat del dueño con Gemini + function calling.
//
// Regla de oro: la IA LEE todo pero NUNCA escribe. Las acciones de escritura
// vuelven a la app como "propuestas" y el dueño las confirma — la ejecución
// real la hace el cliente con sus propios permisos (RLS).
//
// Herramientas de lectura (se ejecutan acá con el JWT del dueño → RLS):
//   list_products, get_store_summary, get_recent_orders
// Herramientas de propuesta (se validan contra la base y se devuelven):
//   propose_product, propose_stock_update, propose_price_update,
//   propose_product_active, propose_product_featured

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const PRIMARY_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";
const FALLBACK_MODEL = "gemini-2.5-flash";
const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
const ALLOWED_MIME = new Set(["image/jpeg", "image/png", "image/webp"]);
const MAX_HISTORY = 20;
const MAX_ROUNDS = 5;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT = `Sos el asistente de IA de AllCommerce para el dueño de un local. Respondés siempre en español rioplatense, tono cercano y profesional, respuestas cortas y concretas.

Podés:
- Analizar fotos de productos que te manda el dueño (título vendedor, descripción, categoría, tags y un precio sugerido en ARS).
- Leer el catálogo, los pedidos y las métricas del local con las herramientas de lectura.
- Proponer cambios sobre el catálogo con las herramientas propose_*. Esas propuestas NO se aplican solas: la app le muestra una tarjeta de confirmación al dueño y él decide.

Reglas:
- NUNCA inventes un product_id. Para referirte a un producto existente llamá primero a list_products y usá el id real.
- Cuando el dueño pida agregar/publicar/crear un producto (con o sin foto), usá propose_product con todos los campos que puedas inferir. Precio: si la foto o el texto no dan pista, proponé un precio razonable del retail argentino y aclaralo.
- Para cambios de stock, precio, pausa o destacado usá las propose_ correspondientes.
- Después de emitir propuestas, explicale al dueño en una oración qué propusiste y que lo confirme con el botón de la tarjeta.
- Si te piden algo fuera del catálogo/pedidos/métricas (config del local, cupones, estados de pedidos), explicá que eso lo hace desde su panel — no tenés herramienta para eso.
- Números con formato argentino ($1.500). Sin markdown pesado: negritas simples y listas cortas están bien.`;

const CATEGORIES = [
  "clothing", "footwear", "accessories", "electronics", "home",
  "beauty", "food", "toys", "stationery", "other",
];

const UNITS = ["unidad", "kg", "g", "lt", "ml", "m", "docena"];

// Declaraciones que ve el modelo ------------------------------------------------

const READ_TOOLS = [
  {
    name: "list_products",
    description:
      "Lista los productos del local (id, título, precio, stock, unidad, activo, destacado). Usala SIEMPRE antes de hablar de un producto existente o proponer cambios sobre él.",
    parameters: {
      type: "OBJECT",
      properties: {
        query: {
          type: "STRING",
          description: "Texto para filtrar por título (opcional)",
        },
        limit: { type: "INTEGER", description: "Máximo de filas (def. 40)" },
      },
    },
  },
  {
    name: "get_store_summary",
    description:
      "Resumen del local: nombre, plan, productos activos, pedidos y ventas del mes, y uso de IA.",
    parameters: { type: "OBJECT", properties: {} },
  },
  {
    name: "get_recent_orders",
    description:
      "Últimos pedidos del local: número, cliente, total, estado y fecha.",
    parameters: {
      type: "OBJECT",
      properties: {
        limit: { type: "INTEGER", description: "Máximo de filas (def. 10)" },
      },
    },
  },
];

const PROPOSE_TOOLS = [
  {
    name: "propose_product",
    description:
      "Propone crear un producto nuevo. El dueño lo confirma en la app. Usala cuando pida agregar/publicar un producto, con foto o sin ella.",
    parameters: {
      type: "OBJECT",
      properties: {
        title: { type: "STRING", description: "Nombre corto y vendedor (máx 60)" },
        description: { type: "STRING", description: "1-3 oraciones" },
        category: { type: "STRING", enum: CATEGORIES },
        price: { type: "NUMBER", description: "Precio de venta en ARS" },
        unit: { type: "STRING", enum: UNITS, description: "Unidad de venta" },
        stock: { type: "NUMBER", description: "Stock inicial (opcional)" },
        track_stock: {
          type: "BOOLEAN",
          description: "true si se controla stock para este producto",
        },
        sku: { type: "STRING", description: "Código/modelo si se ve" },
        tags: {
          type: "ARRAY",
          items: { type: "STRING" },
          description: "3-6 palabras clave minúscula sin acentos",
        },
      },
      required: ["title", "category", "price"],
    },
  },
  {
    name: "propose_stock_update",
    description: "Propone actualizar el stock (o activar/desactivar el control) de un producto existente.",
    parameters: {
      type: "OBJECT",
      properties: {
        product_id: { type: "STRING" },
        product_title: { type: "STRING", description: "Título para mostrar en la confirmación" },
        stock: { type: "NUMBER" },
        track_stock: { type: "BOOLEAN" },
      },
      required: ["product_id", "stock"],
    },
  },
  {
    name: "propose_price_update",
    description: "Propone cambiar el precio de venta de un producto existente.",
    parameters: {
      type: "OBJECT",
      properties: {
        product_id: { type: "STRING" },
        product_title: { type: "STRING" },
        price: { type: "NUMBER", description: "Nuevo precio en ARS" },
      },
      required: ["product_id", "price"],
    },
  },
  {
    name: "propose_product_active",
    description: "Propone pausar (is_active=false) o reactivar un producto existente.",
    parameters: {
      type: "OBJECT",
      properties: {
        product_id: { type: "STRING" },
        product_title: { type: "STRING" },
        is_active: { type: "BOOLEAN" },
      },
      required: ["product_id", "is_active"],
    },
  },
  {
    name: "propose_product_featured",
    description: "Propone marcar o desmarcar un producto como destacado del catálogo.",
    parameters: {
      type: "OBJECT",
      properties: {
        product_id: { type: "STRING" },
        product_title: { type: "STRING" },
        is_featured: { type: "BOOLEAN" },
      },
      required: ["product_id", "is_featured"],
    },
  },
];

const PROPOSE_NAMES = new Set(PROPOSE_TOOLS.map((t) => t.name));

// Utilidades -------------------------------------------------------------------

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function error(status: number, code: string, message: string): Response {
  return json(status, { error: { code, message } });
}

type GeminiPart = Record<string, unknown>;
interface GeminiContent { role?: string; parts: GeminiPart[] }

async function callGemini(
  model: string,
  apiKey: string,
  systemPrompt: string,
  contents: GeminiContent[],
): Promise<Response> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: systemPrompt }] },
      contents,
      tools: [{ functionDeclarations: [...READ_TOOLS, ...PROPOSE_TOOLS] }],
      generationConfig: { temperature: 0.3 },
    }),
  });
}

// Herramientas de lectura (JWT del dueño → RLS limita a su tenant) --------------

async function runReadTool(
  supabase: SupabaseClient,
  tenantId: string,
  name: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  switch (name) {
    case "list_products": {
      const limit = Math.min(Number(args.limit) || 40, 60);
      let q = supabase
        .from("products")
        .select("id, title, price, stock, track_stock, unit, is_active, is_featured, category")
        .eq("tenant_id", tenantId)
        .order("created_at", { ascending: false })
        .limit(limit);
      const query = String(args.query ?? "").trim();
      if (query) q = q.ilike("title", `%${query}%`);
      const { data, error: e } = await q;
      if (e) return { error: e.message };
      return { products: data ?? [], count: data?.length ?? 0 };
    }
    case "get_store_summary": {
      const [{ data: tenant }, { count: products }, { data: monthOrders }] =
        await Promise.all([
          supabase
            .from("tenants")
            .select("name, plan, is_active, is_open")
            .eq("id", tenantId)
            .single(),
          supabase
            .from("products")
            .select("id", { count: "exact", head: true })
            .eq("tenant_id", tenantId)
            .eq("is_active", true),
          supabase
            .from("orders")
            .select("total")
            .eq("tenant_id", tenantId)
            .gte("created_at", new Date(
              new Date().getFullYear(), new Date().getMonth(), 1,
            ).toISOString())
            .neq("status", "rejected"),
        ]);
      const revenue = (monthOrders ?? [])
        .reduce((s: number, o: { total: number }) => s + Number(o.total), 0);
      return {
        name: tenant?.name,
        plan: tenant?.plan,
        is_open: tenant?.is_open,
        active_products: products ?? 0,
        orders_this_month: monthOrders?.length ?? 0,
        revenue_this_month_ars: Math.round(revenue),
      };
    }
    case "get_recent_orders": {
      const limit = Math.min(Number(args.limit) || 10, 30);
      const { data, error: e } = await supabase
        .from("orders")
        .select("order_number, customer_name_snapshot, total, status, created_at")
        .eq("tenant_id", tenantId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (e) return { error: e.message };
      return { orders: data ?? [] };
    }
    default:
      return { error: "unknown_tool" };
  }
}

// Validación de propuestas (no ejecuta, solo confirma que son aplicables) ------

async function validateProposal(
  supabase: SupabaseClient,
  tenantId: string,
  name: string,
  args: Record<string, unknown>,
): Promise<{ ok: boolean; action?: Record<string, unknown>; error?: string }> {
  if (name === "propose_product") {
    const title = String(args.title ?? "").trim().slice(0, 120);
    const price = Number(args.price);
    if (!title) return { ok: false, error: "Falta el título del producto" };
    if (!Number.isFinite(price) || price <= 0) {
      return { ok: false, error: "El precio debe ser un número mayor a 0" };
    }
    const category = CATEGORIES.includes(String(args.category))
      ? String(args.category)
      : "other";
    const unit = UNITS.includes(String(args.unit)) ? String(args.unit) : "unidad";
    const stock = Number(args.stock);
    return {
      ok: true,
      action: {
        type: "product",
        title,
        description: String(args.description ?? "").trim().slice(0, 1000),
        category,
        price: Math.round(price),
        unit,
        stock: Number.isFinite(stock) && stock > 0 ? stock : 0,
        track_stock: args.track_stock === true,
        sku: typeof args.sku === "string" && args.sku.trim()
          ? args.sku.trim().slice(0, 60)
          : null,
        tags: Array.isArray(args.tags)
          ? args.tags.filter((t): t is string => typeof t === "string")
            .map((t) => t.trim().toLowerCase()).filter(Boolean).slice(0, 8)
          : [],
      },
    };
  }

  // El resto de propuestas apuntan a un producto existente: validar que sea del tenant.
  const productId = String(args.product_id ?? "");
  const { data: product } = await supabase
    .from("products")
    .select("id, title, stock, price, is_active, is_featured")
    .eq("id", productId)
    .eq("tenant_id", tenantId)
    .maybeSingle();
  if (!product) {
    return {
      ok: false,
      error: "PRODUCT_NOT_FOUND: el id no existe o no es de tu local. Llamá a list_products y usá un id real.",
    };
  }

  switch (name) {
    case "propose_stock_update": {
      const stock = Number(args.stock);
      if (!Number.isFinite(stock) || stock < 0) {
        return { ok: false, error: "El stock debe ser un número >= 0" };
      }
      return {
        ok: true,
        action: {
          type: "stock_update",
          product_id: product.id,
          product_title: product.title,
          stock,
          track_stock: args.track_stock === false ? false : true,
        },
      };
    }
    case "propose_price_update": {
      const price = Number(args.price);
      if (!Number.isFinite(price) || price <= 0) {
        return { ok: false, error: "El precio debe ser un número mayor a 0" };
      }
      return {
        ok: true,
        action: {
          type: "price_update",
          product_id: product.id,
          product_title: product.title,
          price: Math.round(price),
          previous_price: product.price,
        },
      };
    }
    case "propose_product_active":
      return {
        ok: true,
        action: {
          type: "product_active",
          product_id: product.id,
          product_title: product.title,
          is_active: args.is_active !== false,
        },
      };
    case "propose_product_featured":
      return {
        ok: true,
        action: {
          type: "product_featured",
          product_id: product.id,
          product_title: product.title,
          is_featured: args.is_featured !== false,
        },
      };
    default:
      return { ok: false, error: "Herramienta desconocida" };
  }
}

// Handler ----------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return error(405, "METHOD_NOT_ALLOWED", "Usá POST");
  }

  // 1. Usuario logueado
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

  // 2. Dueño con plan vigente
  const { data: profile } = await supabase
    .from("users")
    .select("role, tenant_id")
    .eq("id", userId)
    .maybeSingle();
  if (!profile || profile.role !== "owner" || !profile.tenant_id) {
    return error(403, "OWNER_REQUIRED", "Solo los dueños pueden usar la IA");
  }
  const tenantId = profile.tenant_id as string;
  const { data: tenant } = await supabase
    .from("tenants")
    .select("is_active, plan_expires_at")
    .eq("id", tenantId)
    .maybeSingle();
  const canPublish = tenant?.is_active === true &&
    new Date(tenant.plan_expires_at).getTime() > Date.now();
  if (!canPublish) {
    return error(403, "PLAN_EXPIRED", "Tu plan está vencido o inactivo");
  }

  // 3. Body
  let body: {
    messages?: Array<{ role?: string; text?: string }>;
    imageBase64?: string;
    mimeType?: string;
  };
  try {
    body = await req.json();
  } catch {
    return error(400, "INVALID_BODY", "Body inválido");
  }
  const incoming = (body.messages ?? [])
    .filter((m) =>
      (m.role === "user" || m.role === "model") &&
      typeof m.text === "string" && m.text.trim().length > 0
    )
    .slice(-MAX_HISTORY);
  if (incoming.length === 0 || incoming[incoming.length - 1].role !== "user") {
    return error(400, "INVALID_BODY", "El último mensaje debe ser del usuario");
  }
  const imageBase64 = body.imageBase64 ?? "";
  const mimeType = body.mimeType ?? "";
  if (imageBase64 && !ALLOWED_MIME.has(mimeType)) {
    return error(400, "INVALID_IMAGE", "Enviá una imagen JPEG, PNG o WebP");
  }
  if (imageBase64.length * 0.75 > MAX_IMAGE_BYTES) {
    return error(413, "IMAGE_TOO_LARGE", "La imagen supera los 2 MB");
  }

  // 4. Cuota (mismo contador que analyze-product)
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

  async function refundAndError(
    status: number,
    code: string,
    message: string,
  ): Promise<Response> {
    const { error: refundErr } = await supabase.rpc("refund_ai_analysis");
    if (refundErr) console.error("refund error", refundErr);
    return error(status, code, message);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return refundAndError(500, "AI_NOT_CONFIGURED", "Falta configurar la IA");
  }

  // 5. Historial → contents de Gemini
  const contents: GeminiContent[] = incoming.map((m) => ({
    role: m.role === "model" ? "model" : "user",
    parts: [{ text: m.text }],
  }));
  // La imagen viaja con el último turno del usuario.
  if (imageBase64) {
    contents[contents.length - 1].parts.push({
      inline_data: { mime_type: mimeType, data: imageBase64 },
    });
  }

  // 6. Loop de function calling: el modelo lee, propone, y responde.
  const actions: Record<string, unknown>[] = [];
  let model = PRIMARY_MODEL;
  let replyText = "";

  for (let round = 0; round < MAX_ROUNDS; round++) {
    let res = await callGemini(model, apiKey, SYSTEM_PROMPT, contents);
    if ((res.status === 429 || res.status === 404) && model !== FALLBACK_MODEL) {
      model = FALLBACK_MODEL;
      res = await callGemini(model, apiKey, SYSTEM_PROMPT, contents);
    }
    if (res.status === 429) {
      return refundAndError(
        429,
        "AI_RATE_LIMITED",
        "La IA está ocupada, probá en un minuto",
      );
    }
    if (!res.ok) {
      console.error("gemini error", model, res.status, await res.text());
      return refundAndError(
        502,
        "AI_UNAVAILABLE",
        "La IA no respondió, probá de nuevo",
      );
    }

    const payload = await res.json();
    const candParts: GeminiPart[] =
      payload?.candidates?.[0]?.content?.parts ?? [];
    if (candParts.length === 0) {
      return refundAndError(502, "AI_EMPTY", "La IA no devolvió respuesta");
    }
    const calls = candParts.filter((p) => p.functionCall != null);
    const texts = candParts
      .map((p) => (typeof p.text === "string" ? p.text : ""))
      .filter((t) => t.length > 0);
    replyText = texts.join("\n").trim() || replyText;

    if (calls.length === 0) break; // respuesta final

    // Devolver resultados de herramientas al modelo.
    contents.push({ role: "model", parts: candParts });
    const responses: GeminiPart[] = [];
    for (const part of calls) {
      const fc = part.functionCall as { name: string; args?: Record<string, unknown> };
      const args = fc.args ?? {};
      let result: unknown;
      if (PROPOSE_NAMES.has(fc.name)) {
        const v = await validateProposal(supabase, tenantId, fc.name, args);
        if (v.ok && v.action) {
          actions.push(v.action);
          result = {
            status: "propuesta registrada",
            note: "La app le muestra la tarjeta de confirmación al dueño.",
          };
        } else {
          result = { error: v.error ?? "propuesta inválida" };
        }
      } else {
        result = await runReadTool(supabase, tenantId, fc.name, args);
      }
      responses.push({
        functionResponse: { name: fc.name, response: { result } },
      });
    }
    contents.push({ role: "user", parts: responses });
  }

  if (!replyText) {
    replyText = actions.length > 0
      ? "Te dejé las propuestas listas para confirmar."
      : "No pude generar una respuesta, probá reformular.";
  }

  return json(200, {
    model,
    reply: replyText,
    actions,
    quota: { used: quota?.used ?? 0, limit: quota?.limit ?? null },
  });
});
