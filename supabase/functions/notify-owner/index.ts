import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.47.10';
import * as admin from 'https://esm.sh/firebase-admin@12.7.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface OrderInfo {
  id: string;
  tenant_id: string;
  order_number: number;
  total: number;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const body = await req.json();

  // Accept either a direct order object or a Supabase realtime/webhook payload.
  const order: OrderInfo | undefined =
    body?.record ?? (body?.tenant_id ? body : undefined);

  if (!order?.tenant_id) {
    return new Response('Missing tenant_id', { status: 400 });
  }

  // Find all users of this tenant.
  const { data: users, error: usersError } = await supabase
    .from('users')
    .select('id')
    .eq('tenant_id', order.tenant_id);

  if (usersError) {
    console.error('Failed to load users:', usersError);
    return new Response('Database error', { status: 500 });
  }

  const userIds = (users ?? []).map((u) => u.id);
  if (userIds.length === 0) {
    console.log('No users for tenant', order.tenant_id);
    return new Response('No users', { status: 200 });
  }

  // Find device tokens for those users.
  const { data: devices, error: devicesError } = await supabase
    .from('user_devices')
    .select('fcm_token')
    .in('user_id', userIds);

  if (devicesError) {
    console.error('Failed to load devices:', devicesError);
    return new Response('Database error', { status: 500 });
  }

  const tokens = (devices ?? []).map((d) => d.fcm_token).filter(Boolean);
  if (tokens.length === 0) {
    console.log('No device tokens for tenant', order.tenant_id);
    return new Response('No devices', { status: 200 });
  }

  if (!FIREBASE_SERVICE_ACCOUNT) {
    console.log(
      'FIREBASE_SERVICE_ACCOUNT not set; skipping push. Tokens:',
      tokens.length,
    );
    return new Response('Firebase not configured', { status: 200 });
  }

  try {
    if (admin.apps.length === 0) {
      const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }

    const title = 'Nuevo pedido';
    const body = `Pedido #${order.order_number} por $${order.total.toLocaleString('es-AR')}`;

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { order_id: order.id, tenant_id: order.tenant_id },
    });

    console.log(
      'FCM success:',
      response.successCount,
      'failure:',
      response.failureCount,
    );
    return Response.json({
      success: response.successCount,
      failure: response.failureCount,
    });
  } catch (e) {
    console.error('FCM error:', e);
    return new Response('FCM error', { status: 500 });
  }
});
