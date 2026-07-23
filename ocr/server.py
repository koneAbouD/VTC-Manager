#!/usr/bin/env python3
"""Micro-service OCR Tesseract pour VTC Manager.

Expose la même API que hertzg/tesseract-server (POST /tesseract, réponse
{"data": {"stdout": ..., "stderr": ..., "exit": ...}}) mais force le mode de
segmentation **psm 6** (bloc de texte uniforme, lu ligne par ligne). C'est
indispensable pour les relevés de contraventions (tableaux multi-colonnes) :
le psm 3 par défaut lit les colonnes séparément et dissocie le code/montant du
numéro. Le langage et le psm restent surchargeables via le champ `options`.
"""
import json
import os
import subprocess
import tempfile

from flask import Flask, request, jsonify

app = Flask(__name__)

DEFAULT_LANGS = ["fra", "eng"]
DEFAULT_PSM = "6"


@app.post("/tesseract")
def tesseract():
    fichier = request.files.get("file")
    if fichier is None:
        return jsonify(error="Champ 'file' manquant"), 400

    options = {}
    brut = request.form.get("options")
    if brut:
        try:
            options = json.loads(brut)
        except ValueError:
            options = {}

    langs = "+".join(options.get("languages") or DEFAULT_LANGS)
    psm = str(options.get("psm", DEFAULT_PSM))

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        fichier.save(tmp.name)
        chemin = tmp.name
    try:
        res = subprocess.run(
            ["tesseract", chemin, "stdout", "-l", langs, "--psm", psm],
            capture_output=True, text=True, timeout=180,
        )
        return jsonify(data={
            "stdout": res.stdout,
            "stderr": res.stderr,
            "exit": res.returncode,
        })
    finally:
        os.unlink(chemin)


@app.get("/health")
def health():
    return "ok", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8884)
