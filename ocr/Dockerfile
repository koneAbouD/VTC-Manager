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

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:8884/health || exit 1

# gunicorn : 2 workers, timeout large (OCR de photos haute résolution).
CMD ["gunicorn", "--bind", "0.0.0.0:8884", "--workers", "2", "--timeout", "180", "server:app"]
