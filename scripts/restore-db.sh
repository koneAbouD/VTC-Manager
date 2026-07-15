#!/usr/bin/env bash
#
# Restauration d'une sauvegarde dans la base PostgreSQL vtc_manager.
#
# ⚠️  DESTRUCTIF : écrase les données existantes de la base cible (--clean).
#     L'hôte par défaut est la PROD (155.133.27.101) → confirmation obligatoire.
#
# Le client pg_restore est choisi automatiquement pour correspondre à la version
# majeure du serveur cible (forçable via PG_BINDIR). Si l'archive a été produite
# par un pg_dump plus récent que le serveur cible, forcez le client adéquat, ex.
#   PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin ./scripts/restore-db.sh …
#
# Le mot de passe n'est JAMAIS écrit dans ce script (env DB_PASSWORD/PGPASSWORD,
# fichier scripts/backup.env, ou saisie masquée).
#
# Usage :
#   ./scripts/restore-db.sh [fichier.dump|.sql]   (sans argument : dernier dump de backups/)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Fichier d'environnement optionnel (gitignoré), en valeurs par défaut ─────
ENV_FILE="${BACKUP_ENV_FILE:-$SCRIPT_DIR/backup.env}"
if [ -f "$ENV_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"; val="${line#*=}"
    [ "$key" = "$line" ] && continue
    if [ -z "${!key:-}" ]; then export "$key=$val"; fi
  done < "$ENV_FILE"
fi

# ── Paramètres ──────────────────────────────────────────────────────────────
DB_HOST="${DB_HOST:-155.133.27.101}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-vtc_manager}"
DB_USERNAME="${DB_USERNAME:-vtc_user}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"
PG_IMAGE="${PG_IMAGE:-postgres:16-alpine}"

# ── Fichier à restaurer (argument, sinon le plus récent de backups/) ────────
FILE="${1:-}"
if [ -z "$FILE" ]; then
  FILE="$(ls -t "$BACKUP_DIR"/*.dump 2>/dev/null | head -1 || true)"
  [ -z "$FILE" ] && { echo "ERREUR : aucun fichier fourni et aucun *.dump dans ${BACKUP_DIR}." >&2; exit 1; }
fi
[ -f "$FILE" ] || { echo "ERREUR : fichier introuvable : ${FILE}" >&2; exit 1; }

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

# ── Client PostgreSQL adapté à la version du serveur ────────────────────────
# shellcheck source=/dev/null
. "$SCRIPT_DIR/pg-client.sh"
select_pg_client

# ── Confirmation (l'opération est destructive) ──────────────────────────────
echo "────────────────────────────────────────────────────────────"
echo "  RESTAURATION"
echo "  Source : ${FILE}"
echo "  Cible  : ${DB_NAME} sur ${DB_HOST}:${DB_PORT} (utilisateur ${DB_USERNAME})"
echo "  ⚠️  Les données actuelles de la base seront ÉCRASÉES."
echo "────────────────────────────────────────────────────────────"
if [ "${ASSUME_YES:-}" != "1" ]; then
  if [ -t 0 ]; then
    read -rp "Retapez le nom de la base pour confirmer (${DB_NAME}) : " CONFIRM
    [ "$CONFIRM" = "$DB_NAME" ] || { echo "Restauration annulée."; exit 1; }
  else
    echo "ERREUR : confirmation requise (terminal) ou ASSUME_YES=1." >&2
    exit 1
  fi
fi

# ── Restauration ────────────────────────────────────────────────────────────
echo "Restauration en cours…"
case "$FILE" in
  *.sql)
    if command -v psql >/dev/null 2>&1; then
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" -v ON_ERROR_STOP=0 -f "$FILE"
    else
      docker run --rm -i -e PGPASSWORD "$PG_IMAGE" \
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" -v ON_ERROR_STOP=0 < "$FILE"
    fi
    ;;
  *)
    if command -v pg_restore >/dev/null 2>&1; then
      pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" \
        --clean --if-exists --no-owner --no-privileges "$FILE"
    elif command -v docker >/dev/null 2>&1; then
      docker run --rm -i -e PGPASSWORD "$PG_IMAGE" \
        pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" \
        --clean --if-exists --no-owner --no-privileges < "$FILE"
    else
      echo "ERREUR : ni pg_restore ni docker disponibles sur cet hôte." >&2
      exit 1
    fi
    ;;
esac

echo "Restauration terminée dans ${DB_NAME} sur ${DB_HOST}."
echo "Note : quelques messages « does not exist » lors du --clean initial sont normaux."
