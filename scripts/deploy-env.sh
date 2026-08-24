#!/bin/sh
# ============================================================
# AA-split staging env generator (run ON the VPS in /opt/aa-split).
# Generates .env with random secrets (no backslash / quoting traps:
#  secrets are computed first into shell vars, then heredoc-expanded).
# ============================================================
set -eu
cd "$(dirname "$0")"

PG=$(openssl rand -hex 16)
J1=$(openssl rand -hex 32)
J2=$(openssl rand -hex 32)
MP=$(openssl rand -hex 24)

umask 077
cat > .env <<EOF
POSTGRES_USER=aa
POSTGRES_PASSWORD=${PG}
POSTGRES_DB=aa_split
DATABASE_URL=postgresql://aa:${PG}@postgres:5432/aa_split?schema=public
REDIS_HOST=redis
REDIS_PORT=6379
JWT_ACCESS_SECRET=${J1}
JWT_REFRESH_SECRET=${J2}
JWT_ACCESS_EXPIRES_IN=30d
JWT_REFRESH_EXPIRES_IN=7d
MINIO_ROOT_USER=aa-minio
MINIO_ROOT_PASSWORD=${MP}
MINIO_BUCKET=aa-receipts
MINIO_USE_SSL=false
MINIO_PUBLIC_ENDPOINT=103.11.77.228:9000
CORS_ORIGINS=*
SWAGGER_ENABLED=true
EOF

echo "env written: $(wc -l < .env) lines"
grep -c '^JWT' .env || true
