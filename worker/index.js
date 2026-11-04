// AllCommerce Worker: serves the Flutter web assets (SPA) and enriches
// public store pages (/s/:slug) with per-tenant SEO meta so link previews
// (WhatsApp, Google, social) show the store name/photo instead of the
// generic AllCommerce tags. Also emits sitemap.xml for crawlers.
//
// Runs before static assets (run_worker_first). Everything that is not a
// store page or the sitemap falls through to env.ASSETS (SPA fallback
// is still handled by the assets binding config).

const SITE_NAME = 'AllCommerce';

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

async function fetchTenant(env, slug, select) {
  const url =
    `${env.SUPABASE_URL}/rest/v1/tenants` +
    `?slug=eq.${encodeURIComponent(slug)}` +
    `&is_public=eq.true&select=${select}`;
  const res = await fetch(url, {
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      Accept: 'application/json',
    },
  });
  if (!res.ok) return [];
  return res.json();
}

function injectMeta(html, meta) {
  const e = escapeHtml;
  let out = html;
  out = out.replace(
    /<title>[^<]*<\/title>/,
    `<title>${e(meta.title)}</title>`,
  );
  out = out.replace(
    /<meta name="description" content="[^"]*">/,
    `<meta name="description" content="${e(meta.description)}">`,
  );
  out = out.replace(
    /<meta property="og:title" content="[^"]*">/,
    `<meta property="og:title" content="${e(meta.title)}">`,
  );
  out = out.replace(
    /<meta property="og:description" content="[^"]*">/,
    `<meta property="og:description" content="${e(meta.description)}">`,
  );
  out = out.replace(
    /<meta property="og:image" content="[^"]*">/,
    `<meta property="og:image" content="${e(meta.image)}">`,
  );
  out = out.replace(
    /<meta name="twitter:card" content="[^"]*">/,
    `<meta name="twitter:card" content="summary_large_image">`,
  );
  out = out.replace(
    /<link rel="canonical" href="[^"]*">/,
    `<link rel="canonical" href="${e(meta.url)}">`,
  );
  out = out.replace(
    /<meta property="og:url" content="[^"]*">/,
    `<meta property="og:url" content="${e(meta.url)}">`,
  );
  const extra =
    `\n  <meta name="twitter:title" content="${e(meta.title)}">\n` +
    `  <meta name="twitter:description" content="${e(meta.description)}">\n` +
    `  <meta name="twitter:image" content="${e(meta.image)}">\n` +
    `  <script type="application/ld+json">${JSON.stringify(meta.jsonLd)}</script>`;
  out = out.replace('</head>', `${extra}\n</head>`);
  return out;
}

async function handleStorePage(request, env, slug) {
  const origin = new URL(request.url).origin;
  const rows = await fetchTenant(
    env,
    slug,
    'name,description,zone,logo_url,cover_url,address',
  );
  // Always serve the SPA shell — unknown/private slugs get generic meta
  // and the app shows its own "store not found" state.
  const tenant = rows[0];
  // The assets binding's SPA fallback already serves index.html for
  // /s/:slug — fetching /index.html directly would 307-redirect to /.
  const assetRes = await env.ASSETS.fetch(request);
  if (!assetRes.ok || !tenant) {
    return assetRes;
  }
  const description =
    (tenant.description && tenant.description.trim()) ||
    `Mirá el catálogo de ${tenant.name}` +
      (tenant.zone ? ` en ${tenant.zone}` : '') +
      ': precios actualizados y pedidos directo por WhatsApp.';
  const meta = {
    title: `${tenant.name} - Catálogo online | ${SITE_NAME}`,
    description,
    url: `${origin}/s/${slug}`,
    image:
      tenant.cover_url ||
      tenant.logo_url ||
      `${origin}/icons/Icon-512.png`,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'Store',
      name: tenant.name,
      description,
      url: `${origin}/s/${slug}`,
      ...(tenant.logo_url ? { logo: tenant.logo_url } : {}),
      ...(tenant.cover_url ? { image: tenant.cover_url } : {}),
      ...(tenant.address
        ? { address: { '@type': 'PostalAddress', streetAddress: tenant.address } }
        : {}),
    },
  };
  const html = injectMeta(await assetRes.text(), meta);
  return new Response(html, {
    status: 200,
    headers: {
      'content-type': 'text/html;charset=UTF-8',
      // Short cache so og updates propagate quickly to scrapers.
      'cache-control': 'public, max-age=300',
    },
  });
}

async function handleSitemap(request, env) {
  const origin = new URL(request.url).origin;
  let rows = [];
  // Fetch all public slugs (RLS on `tenants` limits this to public stores).
  const url =
    `${env.SUPABASE_URL}/rest/v1/tenants` +
    '?is_public=eq.true&select=slug&order=created_at.desc';
  try {
    const res = await fetch(url, {
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
        Accept: 'application/json',
      },
    });
    if (res.ok) rows = await res.json();
  } catch (_) {
    rows = [];
  }
  const urls = rows
    .map(
      (t) =>
        `  <url><loc>${escapeHtml(`${origin}/s/${t.slug}`)}</loc>` +
        '<changefreq>daily</changefreq></url>',
    )
    .join('\n');
  const xml =
    '<?xml version="1.0" encoding="UTF-8"?>\n' +
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' +
    `  <url><loc>${escapeHtml(origin)}/</loc><changefreq>daily</changefreq></url>\n` +
    `  <url><loc>${escapeHtml(origin)}/para-locales</loc><changefreq>weekly</changefreq></url>\n` +
    `${urls}\n</urlset>\n`;
  return new Response(xml, {
    headers: {
      'content-type': 'application/xml;charset=UTF-8',
      'cache-control': 'public, max-age=600',
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const storeMatch = url.pathname.match(/^\/s\/([a-z0-9-]+)\/?$/i);
    if (storeMatch && request.method === 'GET') {
      try {
        return await handleStorePage(request, env, storeMatch[1]);
      } catch (_) {
        // Never break the SPA: fall back to plain assets on any error.
        return env.ASSETS.fetch(request);
      }
    }
    if (url.pathname === '/sitemap.xml' && request.method === 'GET') {
      try {
        return await handleSitemap(request, env);
      } catch (_) {
        return env.ASSETS.fetch(request);
      }
    }
    return env.ASSETS.fetch(request);
  },
};
