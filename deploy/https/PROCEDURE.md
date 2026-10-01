# Passage en HTTPS du VPS (155.133.27.101)

Certificat **Let's Encrypt pour adresse IP** (sans nom de domaine).
Contraintes à connaître :

- validité **6 jours** (profil `shortlived`, imposé pour les IP) → le
  renouvellement automatique n'est pas optionnel : s'il casse, tout tombe en
  moins d'une semaine ;
- certbot **≥ 5.4** (support `--ip-address` + `--webroot`) ;
- le **port 80 doit rester ouvert** sur Internet (défi HTTP-01).

Une seule entrée HTTPS (`https://155.133.27.101`), les applications sont
distinguées par chemin : `/api/` (VTC Manager), `/grafana/`, `/minio/`, `/auth/`.

---

## 0. Sauvegarde et repérage (sur le VPS)

```bash
cd /opt          # dossier du compose d'infra (adapter)
cp -r nginx nginx.bak-$(date +%F)
docker ps --format '{{.Names}}\t{{.Ports}}'
```

Noter le nom exact des conteneurs (backend, keycloak, grafana, minio) et
reporter-les dans `vtc-https.conf` si différents.

## 1. Pare-feu

```bash
ufw allow 80/tcp
ufw allow 443/tcp
ufw status
```

(Aussi dans le pare-feu de l'hébergeur s'il y en a un.)

## 2. Installer certbot récent

```bash
apt remove -y certbot          # la version apt est trop ancienne
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot
certbot --version              # doit afficher >= 5.4
mkdir -p /var/www/certbot
```

## 3. Monter le webroot et les certificats dans nginx

Dans le service `nginx` du compose d'infra :

```yaml
    ports:
      - "80:80"
      - "443:443"
      - "5001:5001"        # transitoire, voir §7
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - /var/www/certbot:/var/www/certbot:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
```

**Avant** d'avoir le certificat, nginx ne démarrerait pas avec le bloc 443.
Donc d'abord, ne garder que le bloc `listen 80` (défi ACME) dans la conf
actuelle, en ajoutant simplement :

```nginx
location /.well-known/acme-challenge/ { root /var/www/certbot; }
```

puis :

```bash
docker compose up -d nginx
echo ok > /var/www/certbot/test.txt
curl http://155.133.27.101/.well-known/acme-challenge/test.txt   # doit afficher ok
rm /var/www/certbot/test.txt
```

## 4. Obtenir le certificat

D'abord en **staging** (pas de quota consommé) :

```bash
certbot certonly --staging --preferred-profile shortlived \
  --webroot --webroot-path /var/www/certbot \
  --ip-address 155.133.27.101 \
  --agree-tos -m talibkone@gmail.com --non-interactive
```

Si OK, en vrai :

```bash
certbot delete --cert-name 155.133.27.101
certbot certonly --preferred-profile shortlived \
  --webroot --webroot-path /var/www/certbot \
  --ip-address 155.133.27.101 \
  --agree-tos -m talibkone@gmail.com --non-interactive
ls /etc/letsencrypt/live/155.133.27.101/
```

## 5. Activer la conf HTTPS

Copier `deploy/https/vtc-https.conf` dans `nginx/conf.d/` du VPS (en
remplacement de l'ancienne conf ; garder les `location` existantes utiles,
ex. flowable), puis :

```bash
docker exec nginx nginx -t && docker exec nginx nginx -s reload
curl -sI https://155.133.27.101/api/tableau-bord   # attendu : 401 (et non 502)
```

**Keycloak (`/auth/`) — à part, en connaissance de cause.** Le backend parle à
Keycloak en interne et les jetons portent un `iss`. Si on fixe `KC_HOSTNAME`
sur l'URL HTTPS publique, l'`iss` change : il faut alors mettre
`KEYCLOAK_ISSUER_URI=https://155.133.27.101/auth/realms/vtc-manager` côté
backend, et **toutes les sessions `offline_access` existantes deviennent
invalides** → chaque utilisateur des deux apps doit se reconnecter et refaire
son code d'accès. Les apps mobiles n'appellent pas Keycloak directement : on
peut donc exposer la console d'admin en HTTPS **sans toucher `KC_HOSTNAME`**,
ou bien la laisser fermée à Internet et y accéder par tunnel SSH
(`ssh -L 8080:localhost:8080 root@155.133.27.101`) — recommandé.

**Grafana / MinIO** : définir les variables indiquées en commentaire dans la
conf, redémarrer ces conteneurs.

## 6. Renouvellement automatique (indispensable)

```bash
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'EOF'
#!/bin/sh
docker exec nginx nginx -s reload
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

systemctl list-timers | grep certbot     # le timer snap tourne 2×/jour
certbot renew --dry-run
```

Surveillance conseillée : un cron quotidien qui alerte si l'expiration est
à moins de 3 jours :

```bash
openssl s_client -connect 155.133.27.101:443 </dev/null 2>/dev/null \
  | openssl x509 -noout -enddate
```

## 7. Bascule des apps mobiles

1. Publier une version des deux apps avec
   `_prodBaseUrl = 'https://155.133.27.101/api'`
   (`mobile/lib/core/network/api_config.dart`,
   `mobile-chauffeur/lib/core/network/api_config.dart`) et
   `android:usesCleartextTraffic="false"` dans les deux `AndroidManifest.xml`.
2. Tant que d'anciennes installations existent, le port **5001 (HTTP)** reste
   servi par le bloc transitoire.
3. Quand tout le monde est à jour : supprimer ce bloc, retirer `5001:5001` du
   compose, `ufw delete allow 5001/tcp`, et passer HSTS à `31536000`.

## 8. Fermer les ports en clair

Les ports publiés directement (8080 Keycloak, 3000 Grafana, 9000/9001 MinIO,
9090 Prometheus, 5432 Postgres…) contournent HTTPS. Les retirer du compose
d'infra ou les bloquer au pare-feu. Pour Postgres, la sauvegarde
(`scripts/backup-db.sh`) passe alors par tunnel SSH.

## Retour arrière

```bash
rm -r nginx && mv nginx.bak-AAAA-MM-JJ nginx
docker compose up -d nginx
```
