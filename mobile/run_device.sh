#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run_device.sh — Lance Flutter sur un vrai téléphone en injectant
#                 automatiquement l'IP locale du Mac comme serveur API.
#
# Usage :
#   ./run_device.sh                  # debug par défaut
#   ./run_device.sh --release        # passer des flags flutter supplémentaires
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PORT=8081

# ── 1. Détection de l'IP locale (WiFi en0, puis Ethernet/USB en1, en2) ───────
IP=""
for iface in en0 en1 en2; do
  CANDIDATE=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
  if [[ -n "$CANDIDATE" ]]; then
    IP="$CANDIDATE"
    IFACE_NAME="$iface"
    break
  fi
done

if [[ -z "$IP" ]]; then
  echo ""
  echo "❌  IP locale non détectée."
  echo "    Connectez-vous au WiFi et réessayez, ou lancez manuellement :"
  echo "    flutter run --dart-define=DEV_HOST=<votre-ip>"
  echo ""
  exit 1
fi

echo ""
echo "✅  IP détectée sur $IFACE_NAME : $IP"
echo "🚀  Backend cible : http://localhost:$PORT/api (via tunnel adb reverse)"

# ── 2. Tunnel ADB reverse (localhost:PORT sur le téléphone → Mac:PORT) ────────
echo "🔌  Configuration du tunnel adb reverse tcp:$PORT tcp:$PORT ..."
if adb reverse tcp:$PORT tcp:$PORT 2>/dev/null; then
  echo "✅  Tunnel actif — localhost:$PORT sur le téléphone pointe vers le Mac."
else
  echo "⚠️   adb reverse échoué — l'app utilisera l'IP directe : $IP"
fi
echo ""

# ── 3. Détection du vrai appareil (exclut web, macos, emulateurs) ─────────────
echo "🔍  Recherche d'un appareil connecté..."

# Format d'une ligne : "  Nom (mobile) • DEVICE_ID • ios • iOS x.x"
# On garde les lignes contenant "• ios" ou "• android" (appareil physique),
# on exclut Simulator / Emulator, et on extrait l'ID (2e champ séparé par •).
DEVICE_ID=$(flutter devices --device-timeout 5 2>/dev/null \
  | grep -E "•[[:space:]]+(ios|android)[[:space:]]" \
  | grep -iv "simulator\|emulator" \
  | head -1 \
  | awk -F'•' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')

echo ""
if [[ -z "$DEVICE_ID" ]]; then
  echo "⚠️   Aucun appareil physique détecté automatiquement."
  echo "    Vérifiez que votre téléphone est branché et déverrouillé,"
  echo "    puis relancez le script."
  echo ""
  echo "    Appareils disponibles :"
  flutter devices
  exit 1
fi

echo "📱  Appareil sélectionné : $DEVICE_ID"
echo ""
flutter run -d "$DEVICE_ID" --dart-define=DEV_HOST="$IP" "$@"
