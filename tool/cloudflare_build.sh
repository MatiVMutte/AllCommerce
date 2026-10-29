#!/usr/bin/env bash
set -euo pipefail

# Build script para Cloudflare Pages.
# Variables de entorno esperadas en Cloudflare Pages > Settings > Environment variables:
#   SUPABASE_URL
#   SUPABASE_ANON_KEY
#   PUBLIC_BASE_URL (opcional, ej. allcommerce.pages.dev)
#   SUPPORT_WHATSAPP (opcional)

if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
PUBLIC_BASE_URL=${PUBLIC_BASE_URL:-}
SUPPORT_WHATSAPP=${SUPPORT_WHATSAPP:-}
FIREBASE_API_KEY=${FIREBASE_API_KEY:-}
FIREBASE_APP_ID=${FIREBASE_APP_ID:-}
FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID:-}
FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-}
FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN:-}
FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET:-}
FIREBASE_MEASUREMENT_ID=${FIREBASE_MEASUREMENT_ID:-}
EOF

flutter pub get
flutter build web --release
