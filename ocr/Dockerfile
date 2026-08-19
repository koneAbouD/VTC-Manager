# Micro-service OCR (Tesseract, psm 6) pour la lecture des relevés et quittances
# de contraventions scannés/photographiés. Voir ocr/server.py.
FROM alpine:3.20

# Tesseract + données fra/eng, Python + Flask + gunicorn (serveur WSGI de prod).
RUN apk add --no-cache \
        tesseract-ocr \
        tesseract-ocr-data-fra \
        tesseract-ocr-data-eng \
        python3 \
        py3-flask \
        py3-gunicorn

WORKDIR /app
COPY server.py .

EXPOSE 8884

# 127.0.0.1 et non « localhost » : gunicorn n'écoute qu'en IPv4 (0.0.0.0) alors
# que le wget de busybox résout « localhost » en ::1 d'abord et échoue avec
# « Connection refused ». Le conteneur passait unhealthy en permanence, et
# autoheal le redémarrait en boucle (OCR injoignable une fois sur deux).
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8884/health || exit 1

# gunicorn : 2 workers, timeout large (OCR de photos haute résolution).
CMD ["gunicorn", "--bind", "0.0.0.0:8884", "--workers", "2", "--timeout", "180", "server:app"]
