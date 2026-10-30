import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.47.10';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: corsHeaders,
  });
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function statusLabel(status: string, deliveryMethod: string): string {
  if (status === 'ready') {
    return deliveryMethod === 'delivery'
      ? 'Va en camino'
      : 'Listo para retirar';
  }
  const labels: Record<string, string> = {
    requested: 'Recibido',
    preparing: 'En preparación',
    delivered: 'Entregado',
    rejected: 'Rechazado',
  };
  return labels[status] ?? 'actualizado';
}

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === 'string'
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/** OAuth2 access token for FCM using the service account (JWT bearer flow). */
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(signature)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`OAuth error ${res.status}: ${await res.text()}`);
  return (await res.json()).access_token as string;
}

Deno.serve(async (req) => {
  // The browser sends a CORS preflight before the real POST — answer it or
  // web clients can never reach this function.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response('Method not allowed', {
      status: 405,
      headers: corsHeaders,
    });
  }

  // Identify the caller from their Supabase JWT.
  const jwt = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (!jwt) return json('Unauthorized', 401);
  const { data: userData } = await admin.auth.getUser(jwt);
  const callerId = userData.user?.id;
  if (!callerId) return json('Unauthorized', 401);

  const body = await req.json().catch(() => ({}));
  const orderId: string | undefined = body?.id;
  if (!orderId) return json('Missing order id', 400);

  const { data: order } = await admin
    .from('orders')
    .select(
      'id, tenant_id, customer_id, order_number, status, delivery_method',
    )
    .eq('id', orderId)
    .maybeSingle();
  if (!order) return json('Not found', 404);

  const { data: tenant } = await admin
    .from('tenants')
    .select('name')
    .eq('id', order.tenant_id)
    .maybeSingle();
  const tenantName = (tenant?.name as string | undefined) ?? 'el local';

  // Only an owner of the order's tenant may notify its customer.
  const { data: caller } = await admin
    .from('users')
    .select('tenant_id')
    .eq('id', callerId)
    .maybeSingle();
  if (!caller || caller.tenant_id !== order.tenant_id) {
    return json('Forbidden', 403);
  }

  const { data: devices } = await admin
    .from('user_devices')
    .select('fcm_token')
    .eq('user_id', order.customer_id);
  const tokens = (devices ?? []).map((d) => d.fcm_token as string).filter(Boolean);
  if (tokens.length === 0) return json({ sent: 0 });

  if (!FIREBASE_SERVICE_ACCOUNT) {
    console.log('FIREBASE_SERVICE_ACCOUNT not set; skipping push');
    return json({ sent: 0, reason: 'not_configured' });
  }

  const sa: ServiceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
  const accessToken = await getAccessToken(sa);
  const label = statusLabel(
    order.status as string,
    (order.delivery_method as string | undefined) ?? 'pickup',
  );

  let sent = 0;
  const invalid: string[] = [];
  for (const token of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: `Tu pedido en ${tenantName}`,
              body: `Pedido #${order.order_number}: ${label}`,
            },
            data: {
              order_id: order.id,
              tenant_id: order.tenant_id,
              status: order.status,
            },
            android: {
              priority: 'HIGH',
              notification: { channel_id: 'order_notifications' },
            },
          },
        }),
      },
    );
    if (res.ok) {
      sent++;
    } else if (res.status === 404 || res.status === 400) {
      invalid.push(token);
    } else {
      console.error('FCM error', res.status, await res.text());
    }
  }

  // Clean up tokens of uninstalled apps.
  if (invalid.length > 0) {
    await admin.from('user_devices').delete().in('fcm_token', invalid);
  }

  return json({ sent, removed: invalid.length });
});
