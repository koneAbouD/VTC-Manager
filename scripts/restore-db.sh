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

# ── Validation de l'archive AVANT toute opération destructive ───────────────
# Un dump vide ou tronqué (sauvegarde interrompue) ne doit jamais amener
# l'utilisateur jusqu'à la confirmation d'écrasement de la base.
[ -s "$FILE" ] || {
  echo "ERREUR : le fichier de sauvegarde est vide : ${FILE}" >&2
  echo "         La sauvegarde a probablement échoué ou été interrompue ; relancez ./scripts/backup-db.sh." >&2
  exit 1
}
case "$FILE" in
  *.sql) ;;
  *)
    if [ "$(head -c 5 "$FILE" 2>/dev/null)" != "PGDMP" ]; then
      echo "ERREUR : ${FILE} n'est pas une archive pg_dump au format custom (en-tête « PGDMP » absent)." >&2
      echo "         Fichier corrompu, incomplet, ou dump SQL à renommer en .sql." >&2
      exit 1
    fi
    ;;
esac

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

# ── Client PostgreSQL capable de lire l'archive ─────────────────────────────
# shellcheck source=/dev/null
. "$SCRIPT_DIR/pg-client.sh"
select_pg_client_for_restore "$FILE"

# ── Versions d'origine et de destination ────────────────────────────────────
SRC_VER=""; DST_VER=""
case "$FILE" in
  *.sql) ;;
  *) if command -v pg_restore >/dev/null 2>&1; then
       SRC_VER="$(pg_restore -l "$FILE" 2>/dev/null \
         | sed -n 's/^;[[:space:]]*Dumped from database version:[[:space:]]*//p' | head -1)"
     fi ;;
esac
if command -v psql >/dev/null 2>&1; then
  DST_VER="$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" \
    -tAc "SHOW server_version" 2>/dev/null | awk '{print $1}')"   # « 15.8 (Debian …) » → « 15.8 »
fi

# ── Confirmation (l'opération est destructive) ──────────────────────────────
echo "────────────────────────────────────────────────────────────"
echo "  RESTAURATION"
echo "  Source : ${FILE} ($(du -h "$FILE" | cut -f1))${SRC_VER:+ — dump issu du serveur v${SRC_VER}}"
echo "  Cible  : ${DB_NAME} sur ${DB_HOST}:${DB_PORT} (utilisateur ${DB_USERNAME})${DST_VER:+ — serveur v${DST_VER}}"
echo "  ⚠️  Les données actuelles de la base seront ÉCRASÉES."
# Restaurer vers une version majeure antérieure n'est pas supporté par PostgreSQL :
# en pratique ça passe, mais le dump peut contenir de la syntaxe que la cible ignore
# (ex. « SET transaction_timeout », apparu en v17 → erreur bénigne sur v16 et moins).
if [ -n "$SRC_VER" ] && [ -n "$DST_VER" ]; then
  SRC_MAJOR="${SRC_VER%%.*}"; DST_MAJOR="${DST_VER%%.*}"
  if [ "${SRC_MAJOR:-0}" -gt "${DST_MAJOR:-0}" ] 2>/dev/null; then
    echo "  ⚠️  Rétrogradation v${SRC_MAJOR} → v${DST_MAJOR} : non supporté officiellement."
    echo "      Quelques erreurs « paramètre inconnu » sont attendues et sans gravité."
  fi
fi
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
# pg_restore sort en 1 dès qu'un seul ordre a échoué (les « does not exist » du
# --clean, un paramètre inconnu de la cible…), sans que la restauration soit
# compromise. On récupère donc le code plutôt que de laisser « set -e » couper.
echo "Restauration en cours…"
RC=0
case "$FILE" in
  *.sql)
    if command -v psql >/dev/null 2>&1; then
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" -v ON_ERROR_STOP=0 -f "$FILE" || RC=$?
    else
      docker run --rm -i -e PGPASSWORD "$PG_IMAGE" \
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" -v ON_ERROR_STOP=0 < "$FILE" || RC=$?
    fi
    ;;
  *)
    if command -v pg_restore >/dev/null 2>&1; then
      pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" \
        --clean --if-exists --no-owner --no-privileges "$FILE" || RC=$?
    elif command -v docker >/dev/null 2>&1; then
      docker run --rm -i -e PGPASSWORD "$PG_IMAGE" \
        pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" \
        --clean --if-exists --no-owner --no-privileges < "$FILE" || RC=$?
    else
      echo "ERREUR : ni pg_restore ni docker disponibles sur cet hôte." >&2
      exit 1
    fi
    ;;
esac

# Contrôle indépendant : une base restaurée contient forcément des tables.
TABLES=""
if command -v psql >/dev/null 2>&1; then
  TABLES="$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" \
    -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null | tr -dc '0-9')"
fi

if [ "$RC" -ne 0 ]; then
  echo "Restauration terminée AVEC ERREURS (code ${RC}) dans ${DB_NAME} sur ${DB_HOST}." >&2
  echo "Sont bénins : « does not exist » du --clean initial, et « unrecognized configuration" >&2
  echo "parameter » quand le dump vient d'une version majeure plus récente que la cible." >&2
  [ -n "$TABLES" ] && echo "Tables présentes dans le schéma public : ${TABLES}." >&2
  echo "Relisez les messages ci-dessus avant de considérer la base utilisable." >&2
  exit "$RC"
fi

echo "Restauration terminée dans ${DB_NAME} sur ${DB_HOST}.${TABLES:+ (${TABLES} tables dans le schéma public)}"
