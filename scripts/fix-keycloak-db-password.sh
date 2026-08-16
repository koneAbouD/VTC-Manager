#!/usr/bin/env bash
#
# Réaligne le mot de passe du rôle PostgreSQL utilisé par Keycloak.
#
# Symptôme traité — Keycloak renvoie 500 « unknown_error » sur /token et ses
# logs portent :
#   FATAL: password authentication failed for user "keycloak"
# Le backend VTC traduit alors la 5xx en 503 AUTH_SERVICE_UNAVAILABLE : plus
# personne ne peut se connecter, ni depuis l'application, ni depuis la console.
#
# Deux modes :
#   --sync    (défaut) Applique au rôle PostgreSQL le mot de passe que Keycloak
#             utilise déjà (lu dans son environnement). Rien n'est réécrit, rien
#             n'est redémarré : c'est le geste minimal qui rétablit le service.
#   --rotate  Change le mot de passe des deux côtés : nouveau secret appliqué au
#             rôle, écrit dans le fichier de configuration de la stack Keycloak
#             (sauvegarde horodatée), puis redémarrage de Keycloak.
#
# Le mot de passe n'est jamais passé en argument (invisible dans « ps »), ni
# journalisé par PostgreSQL (log_statement désactivé le temps de la commande).
#
# Exemples :
#   sudo ./scripts/fix-keycloak-db-password.sh
#   sudo ./scripts/fix-keycloak-db-password.sh --rotate
#   sudo KC_CONTAINER=keycloak PG_CONTAINER=postgres ./scripts/fix-keycloak-db-password.sh
#   sudo NEW_PASSWORD='...' ./scripts/fix-keycloak-db-password.sh --rotate
#
set -euo pipefail

MODE="sync"
RESTART_KC=0

while [ $# -gt 0 ]; do
  case "$1" in
    --sync)    MODE="sync" ;;
    --rotate)  MODE="rotate"; RESTART_KC=1 ;;
    --restart) RESTART_KC=1 ;;
    -h|--help) awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1 (voir --help)" >&2; exit 1 ;;
  esac
  shift
done

info()   { printf '\033[0;36m→\033[0m %s\n' "$*"; }
ok()     { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
alerte() { printf '\033[0;33m!\033[0m %s\n' "$*" >&2; }
echec()  { printf '\033[0;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || echec "docker est introuvable sur cette machine."

# ── Repérage des conteneurs ─────────────────────────────────────────────────
# Un seul candidat attendu ; sinon on demande de trancher par variable, plutôt
# que de deviner et de modifier la mauvaise base.
candidats() {
  docker ps --format '{{.Names}}\t{{.Image}}' | grep -iE "$1" | cut -f1 || true
}

choisir() { # $1=motif $2=nom lisible $3=variable à renseigner
  local liste nb
  liste="$(candidats "$1")"
  nb="$(printf '%s' "$liste" | grep -c . || true)"
  if [ "$nb" -eq 0 ]; then printf ''; return 0; fi
  if [ "$nb" -gt 1 ]; then
    alerte "Plusieurs conteneurs $2 en cours d'exécution :"
    printf '    %s\n' $liste >&2
    echec "Précisez celui à utiliser : $3=<nom> $0 …"
  fi
  printf '%s' "$liste"
}

KC_CONTAINER="${KC_CONTAINER:-$(choisir 'keycloak' 'Keycloak' 'KC_CONTAINER')}"
PG_CONTAINER="${PG_CONTAINER:-$(choisir 'postgres|postgis|pgvector|timescale' 'PostgreSQL' 'PG_CONTAINER')}"

[ -n "$KC_CONTAINER" ] || echec "Conteneur Keycloak introuvable. Renseignez KC_CONTAINER=<nom>."
if [ -z "$PG_CONTAINER" ]; then
  command -v psql >/dev/null 2>&1 \
    || echec "Ni conteneur PostgreSQL ni client psql local. Renseignez PG_CONTAINER=<nom>."
  info "Aucun conteneur PostgreSQL : utilisation du serveur local (sudo -u postgres)."
fi

# ── Paramètres de connexion, lus dans l'environnement de Keycloak ───────────
env_de() { # $1=conteneur $2=clé
  # La sortie est capturée avant d'être filtrée, et le filtre lit tout le flux :
  # avec « pipefail », un « head -n1 » qui coupe la source lui vaudrait un
  # SIGPIPE, et le script mourrait au hasard (code 141) sans un mot.
  local brut
  brut="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$1")"
  printf '%s\n' "$brut" \
    | awk -v k="$2" 'index($0, k "=") == 1 && !trouve { print substr($0, length(k) + 2); trouve = 1 }'
}

KC_URL="$(env_de "$KC_CONTAINER" KC_DB_URL)"
ROLE="$(env_de "$KC_CONTAINER" KC_DB_USERNAME)"
ANCIEN_PW="$(env_de "$KC_CONTAINER" KC_DB_PASSWORD)"
BASE="$(env_de "$KC_CONTAINER" KC_DB_URL_DATABASE)"

# La base peut n'apparaître que dans l'URL JDBC complète.
if [ -z "$BASE" ] && [ -n "$KC_URL" ]; then
  BASE="$(printf '%s' "$KC_URL" | sed -n 's#^jdbc:postgresql://[^/]*/\([^?]*\).*#\1#p')"
fi
ROLE="${ROLE:-keycloak}"
BASE="${BASE:-keycloak}"

[ -n "$ANCIEN_PW" ] || [ "$MODE" = "rotate" ] \
  || echec "KC_DB_PASSWORD absent de l'environnement de « $KC_CONTAINER » : rien à resynchroniser. Utilisez --rotate."

# ── Mot de passe à appliquer ────────────────────────────────────────────────
if [ "$MODE" = "sync" ]; then
  NOUVEAU_PW="$ANCIEN_PW"
else
  NOUVEAU_PW="${NEW_PASSWORD:-}"
  if [ -z "$NOUVEAU_PW" ]; then
    # Alphanumérique : ce secret finit dans un fichier .env et dans une URL
    # JDBC, où « $ », « # » et les guillemets font des dégâts silencieux.
    # La source est bornée dès le premier maillon (head en tête, pas en queue) :
    # « tr </dev/urandom | head » ferait tuer tr par SIGPIPE, donc échouer le
    # script sous pipefail avant même d'avoir rien affiché.
    NOUVEAU_PW="$(LC_ALL=C head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-32)"
    [ "${#NOUVEAU_PW}" -eq 32 ] || echec "Génération du mot de passe incomplète (${#NOUVEAU_PW} caractères)."
    info "Nouveau mot de passe généré (32 caractères alphanumériques)."
  fi
fi

echo
info "Conteneur Keycloak   : $KC_CONTAINER"
info "Serveur PostgreSQL   : ${PG_CONTAINER:-local}"
info "Rôle / base          : $ROLE / $BASE"
info "Mode                 : $MODE$([ "$RESTART_KC" -eq 1 ] && echo ' (avec redémarrage de Keycloak)')"
echo
printf 'Confirmez la modification du rôle « %s » sur cette base (tapez OUI) : ' "$ROLE"
read -r reponse
[ "$reponse" = "OUI" ] || echec "Annulé."

# ── Accès superutilisateur PostgreSQL ───────────────────────────────────────
psql_super() {
  if [ -n "$PG_CONTAINER" ]; then
    docker exec -i -u postgres "$PG_CONTAINER" psql -v ON_ERROR_STOP=1 -q "$@"
  else
    sudo -u postgres psql -v ON_ERROR_STOP=1 -q "$@"
  fi
}

psql_super -d postgres -tAc 'SELECT 1' >/dev/null \
  || echec "Impossible d'ouvrir une session superutilisateur PostgreSQL."

# Échappement d'un littéral SQL. Via sed plutôt que ${var//'/''} : le
# remplacement de motif bash conserve les antislashs et son comportement varie
# d'une version à l'autre — un mot de passe contenant une apostrophe passerait
# alors tronqué, sans que rien ne le signale.
sql_quote() { printf '%s' "$1" | sed "s/'/''/g"; }
# Un identifiant (nom de rôle) se protège en doublant les guillemets doubles,
# pas les apostrophes.
ident_quote() { printf '%s' "$1" | sed 's/"/""/g'; }

# Même précaution que dans env_de : pas de « grep -q » en bout de tuyau, qui
# couperait psql et ferait remonter un SIGPIPE à travers pipefail.
ROLE_EXISTE="$(psql_super -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$(sql_quote "$ROLE")'")"
[ "$ROLE_EXISTE" = "1" ] \
  || echec "Le rôle « $ROLE » n'existe pas sur ce serveur — ce n'est probablement pas la bonne instance."

# ── Application du mot de passe ─────────────────────────────────────────────
# Le SQL passe par l'entrée standard (rien dans « ps ») et log_statement est
# coupé pour la session, afin que le secret n'atterrisse pas dans les journaux.
psql_super -d postgres <<SQL
SET log_statement = 'none';
ALTER ROLE "$(ident_quote "$ROLE")" WITH LOGIN PASSWORD '$(sql_quote "$NOUVEAU_PW")';
SQL
ok "Mot de passe appliqué au rôle « $ROLE »."

# ── Vérification : connexion réelle avec ce mot de passe ────────────────────
# Depuis la pile réseau du conteneur Keycloak, en visant l'hôte de son URL JDBC :
# c'est le chemin exact qu'il emprunte, donc la seule ligne de pg_hba.conf qui
# nous intéresse. Surtout pas via 127.0.0.1 dans le conteneur PostgreSQL :
# l'image officielle y accorde « trust », et le test répondrait OK avec
# n'importe quel mot de passe.
HOTE_PORT="$(printf '%s' "$KC_URL" | sed -n 's#^jdbc:postgresql://\([^/?]*\).*#\1#p')"
DB_HOTE="${HOTE_PORT%%:*}"
DB_PORT="${HOTE_PORT#*:}"
[ "$DB_PORT" = "$DB_HOTE" ] && DB_PORT=5432

if [ -n "$DB_HOTE" ] && [ -n "$PG_CONTAINER" ]; then
  # Même image que le serveur : psql est présent et rien n'est à télécharger.
  PG_IMAGE="$(docker inspect -f '{{.Config.Image}}' "$PG_CONTAINER")"
  if printf '%s\n' "$NOUVEAU_PW" | docker run --rm -i --network "container:$KC_CONTAINER" \
        "$PG_IMAGE" sh -c 'read -r p; PGPASSWORD=$p psql -h "$0" -p "$1" -U "$2" -d "$3" -tAc "SELECT 1"' \
        "$DB_HOTE" "$DB_PORT" "$ROLE" "$BASE" >/dev/null 2>&1; then
    ok "Connexion $ROLE@$DB_HOTE:$DB_PORT/$BASE vérifiée depuis le réseau de Keycloak."
  else
    echec "Le mot de passe est posé, mais la connexion échoue encore par le chemin de Keycloak ($DB_HOTE:$DB_PORT/$BASE) : vérifiez pg_hba.conf (scram-sha-256 attendu pour ce réseau) et le nom de la base."
  fi
else
  alerte "Vérification réseau impossible (URL JDBC ou conteneur PostgreSQL inconnus) : contrôlez les logs de Keycloak après redémarrage."
fi

# ── Contrôle de sûreté : la base contient-elle encore le realm ? ────────────
# Une authentification qui casse du jour au lendemain vient souvent d'un volume
# PostgreSQL recréé. Dans ce cas le mot de passe n'est que la partie visible :
# le realm, les clients et les comptes ont disparu avec l'ancien volume.
REALMS="$(psql_super -d "$BASE" -tAc 'SELECT count(*) FROM realm' 2>/dev/null || echo 'n/a')"
if [ "$REALMS" = "n/a" ]; then
  alerte "La table « realm » est introuvable dans « $BASE » : la base semble vide ou recréée. Restaurez une sauvegarde Keycloak avant d'aller plus loin."
elif [ "$REALMS" = "0" ]; then
  alerte "Aucun realm dans « $BASE » : base neuve. Il faudra réimporter le realm."
else
  ok "Base « $BASE » : $REALMS realm(s) présent(s)."
fi

# ── Mode --rotate : propager le secret à la configuration de Keycloak ───────
if [ "$MODE" = "rotate" ]; then
  echo
  info "Propagation du nouveau mot de passe à la configuration de « $KC_CONTAINER »…"

  WORKDIR="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$KC_CONTAINER" 2>/dev/null || true)"
  CONFIGS="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project.config_files"}}' "$KC_CONTAINER" 2>/dev/null || true)"

  # On repère les fichiers par la *valeur* de l'ancien mot de passe : peu
  # importe le nom de la variable (KC_DB_PASSWORD, KEYCLOAK_DB_PASSWORD…) ou
  # qu'elle soit posée en dur dans le compose.
  CIBLES=""
  if [ -n "$ANCIEN_PW" ]; then
    for f in ${CONFIGS//,/ } "${WORKDIR:+$WORKDIR/.env}"; do
      [ -f "$f" ] || continue
      # « if » et non « grep && … » : sous set -e, un fichier sans le secret
      # ferait sortir le script au lieu de passer au suivant.
      if grep -qF -- "$ANCIEN_PW" "$f"; then CIBLES="$CIBLES $f"; fi
    done
  fi

  if [ -z "$CIBLES" ]; then
    alerte "Aucun fichier de configuration contenant l'ancien secret n'a été trouvé${WORKDIR:+ dans $WORKDIR}."
    alerte "Reportez le nouveau mot de passe à la main (variable KC_DB_PASSWORD), puis redémarrez Keycloak."
    alerte "Nouveau mot de passe : $NOUVEAU_PW"
  else
    horodatage="$(date +%Y%m%d-%H%M%S)"
    for f in $CIBLES; do
      cp -p "$f" "$f.bak-$horodatage"
      tmp="$(mktemp)"
      # Remplacement littéral (awk/index) : le secret n'est pas une regex.
      awk -v old="$ANCIEN_PW" -v new="$NOUVEAU_PW" '
        { i = index($0, old)
          if (i > 0) $0 = substr($0, 1, i-1) new substr($0, i + length(old))
          print }
      ' "$f" > "$tmp"
      cat "$tmp" > "$f"   # préserve propriétaire et permissions du fichier
      rm -f "$tmp"
      ok "Mis à jour : $f (sauvegarde : $f.bak-$horodatage)"
    done
  fi
fi

# ── Redémarrage de Keycloak ─────────────────────────────────────────────────
if [ "$RESTART_KC" -eq 1 ]; then
  info "Redémarrage de « $KC_CONTAINER »…"
  docker restart "$KC_CONTAINER" >/dev/null
  ok "Keycloak redémarré."
else
  info "Pas de redémarrage : Keycloak rétablit ses connexions de lui-même (pool Agroal)."
fi

echo
ok "Terminé. Contrôlez que plus aucune erreur d'authentification ne remonte :"
echo "    docker logs --since 2m $KC_CONTAINER 2>&1 | grep -i 'password authentication'"
echo "    docker logs --since 2m vtc-manager-backend 2>&1 | grep -i AUTH_SERVICE_UNAVAILABLE"
