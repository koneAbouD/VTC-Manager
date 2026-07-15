# shellcheck shell=bash
#
# Sélection du client PostgreSQL (pg_dump / pg_restore / psql) adapté à la version
# MAJEURE du serveur cible — sourcé par backup-db.sh et restore-db.sh.
#
# Pourquoi : un client de version différente du serveur provoque des
# incompatibilités (dump illisible par un client plus ancien ; paramètres inconnus
# comme « transaction_timeout » émis vers un serveur plus ancien). On aligne donc
# le client sur le serveur : Homebrew postgresql@16 pour un serveur 13→16,
# postgresql@17 pour un serveur 17, libpq (18) pour un serveur 18.
#
# Variables attendues : DB_HOST DB_PORT DB_NAME DB_USERNAME PGPASSWORD.
# PG_BINDIR force un répertoire de binaires précis (court-circuite la détection).

_pg_bootstrap_psql() {
  local p d
  p="$(command -v psql 2>/dev/null || true)"
  [ -n "$p" ] && { echo "$p"; return 0; }
  for d in /opt/homebrew/opt/postgresql@17/bin /opt/homebrew/opt/postgresql@16/bin \
           /opt/homebrew/opt/libpq/bin /usr/local/opt/postgresql@17/bin \
           /usr/local/opt/postgresql@16/bin /usr/local/opt/libpq/bin; do
    [ -x "$d/psql" ] && { echo "$d/psql"; return 0; }
  done
  return 1
}

select_pg_client() {
  # 1. Répertoire forcé.
  if [ -n "${PG_BINDIR:-}" ] && [ -x "$PG_BINDIR/pg_dump" ]; then
    PATH="$PG_BINDIR:$PATH"; export PATH; return 0
  fi

  # 2. Version majeure du serveur (n'importe quel psql sait lire server_version_num).
  local boot major=""
  boot="$(_pg_bootstrap_psql || true)"
  if [ -n "$boot" ]; then
    major="$("$boot" -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USERNAME" -d "$DB_NAME" \
      -tAc "SELECT current_setting('server_version_num')::int/10000" 2>/dev/null | tr -dc '0-9' || true)"
  fi

  # 3. Répertoires candidats : la version alignée d'abord, puis replis (un client
  #    plus récent sait toujours dumper un serveur plus ancien).
  local prefer="" d
  case "$major" in
    17)          prefer="/opt/homebrew/opt/postgresql@17/bin /usr/local/opt/postgresql@17/bin" ;;
    13|14|15|16) prefer="/opt/homebrew/opt/postgresql@16/bin /usr/local/opt/postgresql@16/bin" ;;
    18)          prefer="/opt/homebrew/opt/libpq/bin /usr/local/opt/libpq/bin" ;;
  esac
  for d in $prefer \
           /opt/homebrew/opt/postgresql@17/bin /opt/homebrew/opt/postgresql@16/bin \
           /opt/homebrew/opt/libpq/bin /usr/local/opt/postgresql@17/bin \
           /usr/local/opt/postgresql@16/bin /usr/local/opt/libpq/bin; do
    if [ -x "$d/pg_dump" ]; then
      PATH="$d:$PATH"; export PATH
      [ -n "$major" ] && echo "Client PostgreSQL : $("$d/pg_dump" --version | awk '{print $3}') (serveur v${major})" >&2
      return 0
    fi
  done
  return 0   # aucun client local : les scripts retomberont sur Docker
}
