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

# ── Sélection pour la RESTAURATION ──────────────────────────────────────────
# Contrainte différente du dump : c'est l'ARCHIVE qui commande, pas le serveur.
# Une archive au format custom produite par pg_dump 17 (version 1.16) est
# illisible par un pg_restore 16 (« unsupported version (1.16) in file header »),
# même si le serveur cible est un v15. On prend donc le client suffisant le plus
# proche du serveur, et non le client aligné sur le serveur.

# Version majeure minimale de client capable de lire l'archive custom passée en
# argument. L'en-tête porte « PGDMP » puis vmaj, vmin, vrev sur un octet chacun.
_pg_archive_min_client() {
  local file="$1" vmaj vmin
  [ "$(head -c 5 "$file" 2>/dev/null)" = "PGDMP" ] || return 1
  vmaj="$(od -An -tu1 -j5 -N1 "$file" 2>/dev/null | tr -dc '0-9')"
  vmin="$(od -An -tu1 -j6 -N1 "$file" 2>/dev/null | tr -dc '0-9')"
  [ "$vmaj" = "1" ] && [ -n "$vmin" ] || return 1
  if   [ "$vmin" -ge 16 ]; then echo $(( vmin + 1 ))  # 1.16 → 17, et ainsi de suite
  elif [ "$vmin" -eq 15 ]; then echo 16
  else                          echo 13               # 1.14 et antérieures
  fi
}

_pg_major_of() { "$1/pg_restore" --version 2>/dev/null | awk '{print $3}' | cut -d. -f1 | tr -dc '0-9'; }

select_pg_client_for_restore() {
  local file="$1"

  # 1. Répertoire forcé.
  if [ -n "${PG_BINDIR:-}" ] && [ -x "$PG_BINDIR/pg_restore" ]; then
    PATH="$PG_BINDIR:$PATH"; export PATH; return 0
  fi

  # 2. Archive illisible ou dump SQL : rien à déduire, on garde la logique serveur.
  local need
  need="$(_pg_archive_min_client "$file" 2>/dev/null || true)"
  [ -n "$need" ] || { select_pg_client; return 0; }

  # 3. Parmi les clients installés : le plus ancien qui sait lire l'archive
  #    (au plus proche du serveur cible), sinon le plus récent disponible.
  local d m best="" bestm=0 newest="" newestm=0
  for d in /opt/homebrew/opt/postgresql@16/bin /opt/homebrew/opt/postgresql@17/bin \
           /opt/homebrew/opt/libpq/bin /usr/local/opt/postgresql@16/bin \
           /usr/local/opt/postgresql@17/bin /usr/local/opt/libpq/bin; do
    [ -x "$d/pg_restore" ] || continue
    m="$(_pg_major_of "$d")"; [ -n "$m" ] || continue
    [ "$m" -gt "$newestm" ] && { newestm="$m"; newest="$d"; }
    if [ "$m" -ge "$need" ] && { [ "$bestm" -eq 0 ] || [ "$m" -lt "$bestm" ]; }; then
      bestm="$m"; best="$d"
    fi
  done

  if [ -n "$best" ]; then
    PATH="$best:$PATH"; export PATH
    echo "Client PostgreSQL : $("$best/pg_restore" --version | awk '{print $3}') (archive lisible à partir de v${need})" >&2
    return 0
  fi

  if [ -n "$newest" ]; then
    PATH="$newest:$PATH"; export PATH
    echo "ATTENTION : aucun client v${need}+ installé ; tentative avec le plus récent (v${newestm})." >&2
    echo "            Si la lecture échoue : brew install postgresql@${need}" >&2
    return 0
  fi
  return 0   # aucun client local : repli Docker
}
