import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.47.10';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
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
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
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
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  // Identify the caller from their Supabase JWT.
  const jwt = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (!jwt) return new Response('Unauthorized', { status: 401 });
  const { data: userData } = await admin.auth.getUser(jwt);
  const callerId = userData.user?.id;
  if (!callerId) return new Response('Unauthorized', { status: 401 });

  const body = await req.json().catch(() => ({}));
  const orderId: string | undefined = body?.id;
  if (!orderId) return new Response('Missing order id', { status: 400 });

  // Only the customer who placed the order can trigger its notification.
  const { data: order } = await admin
    .from('orders')
    .select('id, tenant_id, order_number, total, customer_id')
    .eq('id', orderId)
    .maybeSingle();
  if (!order || order.customer_id !== callerId) {
    return new Response('Forbidden', { status: 403 });
  }

  const { data: owners } = await admin
    .from('users')
    .select('id')
    .eq('tenant_id', order.tenant_id);
  const ownerIds = (owners ?? []).map((u) => u.id);
  if (ownerIds.length === 0) return Response.json({ sent: 0 });

  const { data: devices } = await admin
    .from('user_devices')
    .select('fcm_token')
    .in('user_id', ownerIds);
  const tokens = (devices ?? []).map((d) => d.fcm_token as string).filter(Boolean);
  if (tokens.length === 0) return Response.json({ sent: 0 });

  if (!FIREBASE_SERVICE_ACCOUNT) {
    console.log('FIREBASE_SERVICE_ACCOUNT not set; skipping push');
    return Response.json({ sent: 0, reason: 'not_configured' });
  }

  const sa: ServiceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
  const accessToken = await getAccessToken(sa);
  const total = Number(order.total).toLocaleString('es-AR');

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
              title: 'Nuevo pedido',
              body: `Pedido #${order.order_number} por $${total}`,
            },
            data: { order_id: order.id, tenant_id: order.tenant_id },
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

  return Response.json({ sent, removed: invalid.length });
});
