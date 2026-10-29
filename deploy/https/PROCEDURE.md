# Passage en HTTPS du VPS (155.133.27.101) — par nom de domaine

Certificat **Let's Encrypt classique (90 jours)** pour trois sous-domaines :

| Nom | Rôle |
|---|---|
| `api.<domaine>` | API des deux apps mobiles (`/api/`) |
| `s3.<domaine>` | API S3 de MinIO : URLs signées des photos et documents |
| `grafana.<domaine>` | Grafana (facultatif) |

La console MinIO, Keycloak et Prometheus ne sont **pas** publiés : accès par
tunnel SSH (§8).

Dans tout le dépôt, `tmk.example` est un domaine factice qui ne résout jamais.
Il est à remplacer par le vrai domaine dans :

- `deploy/https/vtc-https.conf` ;
- `mobile/lib/core/network/api_config.dart` et
  `mobile-chauffeur/lib/core/network/api_config.dart` (`_prodBaseUrl`) ;
- le `.env` du VPS (`MINIO_PUBLIC_ENDPOINT`).

```bash
grep -rn "tmk\.example" --exclude-dir=.git .
```

---

## 0. Domaine et DNS

1. Acheter le domaine (ex. `.ci` ou `.com`).
2. Chez le registrar, créer trois enregistrements **A** vers `155.133.27.101` :
   `api`, `s3`, `grafana`. Aucun AAAA, sauf si le VPS a une IPv6 servie par
   nginx.
3. Vérifier la propagation avant d'aller plus loin :

```bash
for h in api s3 grafana; do dig +short $h.<domaine>; done   # → 155.133.27.101
```

## 1. Sauvegarde et repérage (sur le VPS)

```bash
cd /opt          # dossier du compose d'infra (adapter)
cp -r nginx nginx.bak-$(date +%F)
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Networks}}'
grep -rn proxy_pass nginx/conf.d/
```

À vérifier :

- les noms exacts des conteneurs (backend, minio, grafana), à reporter dans
  `vtc-https.conf` s'ils diffèrent ;
- **nginx joint le backend par son nom de conteneur** (`vtc-manager-backend:8081`),
  sur le même réseau Docker. Si l'actuelle conf vise l'IP de l'hôte ou
  `172.17.0.1:8081`, le passage du port backend sur `127.0.0.1` (compose.prod.yml)
  la casserait : brancher d'abord nginx sur le réseau infra.

## 2. Pare-feu

```bash
ufw allow 80/tcp
ufw allow 443/tcp
ufw status
```

(Aussi dans le pare-feu de l'hébergeur s'il y en a un.) Le port 80 reste
ouvert en permanence : il sert au renouvellement du certificat.

## 3. Certbot et webroot

```bash
apt install -y certbot       # la version apt suffit pour un domaine
mkdir -p /var/www/certbot
```

Dans le service `nginx` du compose d'infra :

```yaml
    ports:
      - "80:80"
      - "443:443"
      - "5001:5001"        # transitoire, voir §9
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - /var/www/certbot:/var/www/certbot:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
```

**Avant** d'avoir le certificat, nginx refuserait de démarrer avec les blocs
443. On ne garde donc d'abord que le bloc `listen 80` (défi ACME) dans la conf
actuelle, en ajoutant :

```nginx
location /.well-known/acme-challenge/ { root /var/www/certbot; }
```

puis :

```bash
docker compose up -d nginx
echo ok > /var/www/certbot/test.txt
curl http://api.<domaine>/.well-known/acme-challenge/test.txt   # doit afficher ok
rm /var/www/certbot/test.txt
```

## 4. Obtenir le certificat

Un seul certificat (nommé `vtc`) couvre les trois noms. D'abord en
**staging** (aucun quota consommé) :

```bash
certbot certonly --staging --cert-name vtc \
  --webroot --webroot-path /var/www/certbot \
  -d api.<domaine> -d s3.<domaine> -d grafana.<domaine> \
  --agree-tos -m talibkone@gmail.com --non-interactive
```

Si OK, en vrai :

```bash
certbot delete --cert-name vtc
certbot certonly --cert-name vtc \
  --webroot --webroot-path /var/www/certbot \
  -d api.<domaine> -d s3.<domaine> -d grafana.<domaine> \
  --agree-tos -m talibkone@gmail.com --non-interactive
ls /etc/letsencrypt/live/vtc/        # fullchain.pem, privkey.pem
```

## 5. Activer la conf HTTPS

```bash
sed -i 's/tmk\.example/<domaine>/g' vtc-https.conf
```

Copier `vtc-https.conf` dans `nginx/conf.d/` du VPS, à la place de l'ancienne
conf. Garder les `location` existantes encore utiles (ex. flowable). Puis :

```bash
docker exec nginx nginx -t && docker exec nginx nginx -s reload
curl -sI https://api.<domaine>/api/tableau-bord    # attendu : 401 (et non 502)
curl -sI https://api.<domaine>/actuator/health     # attendu : 404 (non publié)
curl -sI https://s3.<domaine>/minio/health/live    # attendu : 200
```

Puis vérifier la note sur https://www.ssllabs.com/ssltest/ (objectif : **A**).

**Grafana** : `GF_SERVER_ROOT_URL=https://grafana.<domaine>/`, puis
redémarrer le conteneur.

## 6. Backend

Dans le `.env` du VPS :

```dotenv
MINIO_PUBLIC_ENDPOINT=https://s3.<domaine>
CORS_ALLOWED_ORIGINS=
PAYMENT_CALLBACK_BASE_URL=https://api.<domaine>   # webhooks agrégateur
```

puis redéployer le backend (nouvelle image) :

```bash
docker compose -f compose.prod.yml --env-file .env up -d --build backend
docker logs vtc-manager-backend | grep "URLs MinIO signées"   # → https://s3.<domaine>
```

Ce que contient cette version du backend :

- les URLs signées (photos des chauffeurs et des véhicules, documents) visent
  `https://s3.<domaine>` au lieu du nom interne `minio:9000`, que les
  téléphones ne peuvent pas joindre ;
- `forward-headers-strategy: native` : Spring sait qu'il est derrière HTTPS ;
- Actuator limité à `health` (sans détails), Swagger et OpenAPI désactivés en
  prod, CORS fermé ;
- port 8081 publié sur `127.0.0.1` seulement.

**Keycloak : ne pas toucher `KC_HOSTNAME`.** Le backend parle à Keycloak en
interne et les jetons portent un `iss`. Le modifier invaliderait toutes les
sessions `offline_access` : chaque utilisateur des deux apps devrait se
reconnecter et refaire son code d'accès. Les apps n'appellent jamais Keycloak
directement, donc rien ne l'impose.

## 7. Renouvellement automatique et surveillance

```bash
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'EOF'
#!/bin/sh
docker exec nginx nginx -s reload
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

systemctl list-timers | grep certbot     # le timer tourne 2×/jour
certbot renew --dry-run
```

Certbot renouvelle à 30 jours de l'échéance. Ajouter un cron quotidien qui
alerte si l'expiration approche de **14 jours**, signe que le renouvellement
est cassé :

```bash
echo | openssl s_client -connect api.<domaine>:443 -servername api.<domaine> 2>/dev/null \
  | openssl x509 -noout -checkend $((14*86400)) || echo "Certificat VTC : expiration < 14 jours"
```

Let's Encrypt n'envoie plus d'e-mail avant l'expiration : cette alerte est
la seule.

## 8. Fermer les ports en clair

Les ports publiés directement (3000 Grafana, 9000/9001 MinIO, 9090
Prometheus, 8080 Keycloak, 5432 Postgres) contournent HTTPS.

**Attention : Docker contourne `ufw`.** Un port déclaré en `ports:` est ouvert
par les règles iptables de Docker, même si `ufw` le bloque. Pour les fermer, il
faut retirer ces `ports:` du compose d'infra ou les lier à la boucle locale
(`"127.0.0.1:9001:9001"`).

Accès d'administration par tunnel SSH :

```bash
ssh -L 9001:localhost:9001 -L 8080:localhost:8080 -L 9090:localhost:9090 root@155.133.27.101
# puis http://localhost:9001 (console MinIO), :8080 (Keycloak), :9090 (Prometheus)
```

Pour Postgres, `scripts/backup-db.sh` passe alors par un tunnel
(`ssh -L 5432:localhost:5432 …` puis `DB_HOST=localhost`).

Contrôle depuis l'extérieur :

```bash
for p in 3000 5432 8080 8081 9000 9001 9090; do nc -z -G 3 155.133.27.101 $p && echo "$p OUVERT"; done
```

## 9. Bascule des apps mobiles

1. Remplacer `tmk.example` par le domaine dans les deux `api_config.dart`,
   puis publier les deux apps. Le manifeste Android de release interdit
   désormais le HTTP (`usesCleartextTraffic="false"`). Il reste autorisé en
   debug et profile pour le backend local.
2. Tant que d'anciennes installations existent, le port **5001 (HTTP)** reste
   servi par le bloc transitoire.
3. Quand tout le monde est à jour : supprimer ce bloc, retirer `5001:5001` du
   compose, `ufw delete allow 5001/tcp`, et passer HSTS à `31536000` sur les
   trois noms.

## Retour arrière

```bash
rm -r nginx && mv nginx.bak-AAAA-MM-JJ nginx
docker compose up -d nginx
```

Côté backend, vider `MINIO_PUBLIC_ENDPOINT` ramène les URLs signées sur
`MINIO_ENDPOINT`.
