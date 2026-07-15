#!/usr/bin/env bash
#
# Sauvegarde de la base PostgreSQL vtc_manager (format custom, compressé).
#
# Le client pg_dump est choisi automatiquement pour correspondre à la version
# majeure du serveur cible (évite les dumps illisibles ou les paramètres inconnus
# comme « transaction_timeout »). Forçable via PG_BINDIR.
#
# Le mot de passe n'est JAMAIS écrit dans ce script (env DB_PASSWORD/PGPASSWORD,
# fichier scripts/backup.env, ou saisie masquée).
#
# Exemples :
#   ./scripts/backup-db.sh
#   DB_HOST=localhost DB_PASSWORD=vtc_password ./scripts/backup-db.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Fichier d'environnement optionnel (gitignoré), en valeurs par défaut ─────
# Une variable déjà présente dans l'environnement (ligne de commande) prime.
ENV_FILE="${BACKUP_ENV_FILE:-$SCRIPT_DIR/backup.env}"
if [ -f "$ENV_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"; val="${line#*=}"
    [ "$key" = "$line" ] && continue
    if [ -z "${!key:-}" ]; then export "$key=$val"; fi
  done < "$ENV_FILE"
fi

# ── Paramètres (surchargeables par l'environnement) ─────────────────────────
DB_HOST="${DB_HOST:-155.133.27.101}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-vtc_manager}"
DB_USERNAME="${DB_USERNAME:-vtc_user}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"      # 0 = ne rien supprimer
PG_IMAGE="${PG_IMAGE:-postgres:16-alpine}"  # dernier recours (aucun client local)

# ── Mot de passe (jamais en dur) ────────────────────────────────────────────
PGPASSWORD="${PGPASSWORD:-${DB_PASSWORD:-}}"
if [ -z "$PGPASSWORD" ]; then
  if [ -t 0 ]; then
    read -rsp "Mot de passe pour ${DB_USERNAME}@${DB_HOST}/${DB_NAME} : " PGPASSWORD; echo
  else
    echo "ERREUR : aucun mot de passe (DB_PASSWORD / PGPASSWORD / backup.env) et pas de terminal." >&2
    exit 1
  fi
fi
export PGPASSWORD

# ── Sélection du client PostgreSQL adapté à la version du serveur ───────────
# shellcheck source=/dev/null
. "$SCRIPT_DIR/pg-client.sh"
select_pg_client   # ajuste PATH ; laisse le repli Docker si aucun client local

# ── Sauvegarde ──────────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_DIR/${DB_NAME}_${TS}.dump"

echo "Sauvegarde de ${DB_NAME} sur ${DB_HOST}:${DB_PORT} → ${OUT}"
trap 'rm -f "$OUT"' ERR   # pas de dump partiel en cas d'échec

if command -v pg_dump >/dev/null 2>&1; then
  pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" \
    --format=custom --no-owner --file "$OUT"
elif command -v docker >/dev/null 2>&1; then
  docker run --rm -e PGPASSWORD "$PG_IMAGE" \
    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" \
    --format=custom --no-owner > "$OUT"
else
  echo "ERREUR : ni pg_dump ni docker disponibles sur cet hôte." >&2
  exit 1
fi

trap - ERR

if [ ! -s "$OUT" ]; then
  echo "ÉCHEC : le fichier de sauvegarde est vide." >&2
  rm -f "$OUT"; exit 1
fi

echo "Sauvegarde réussie ($(du -h "$OUT" | cut -f1)) : ${OUT}"

# ── Rétention : purge des dumps trop anciens ────────────────────────────────
if [ "${RETENTION_DAYS}" -gt 0 ]; then
  find "$BACKUP_DIR" -name "${DB_NAME}_*.dump" -type f -mtime +"${RETENTION_DAYS}" -print -delete \
    | sed 's/^/Supprimé (rétention) : /' || true
fi
