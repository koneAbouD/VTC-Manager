package com.tmk.vtcmanager.application.ports.storage;

/**
 * Compresse un document (relevé / quittance) avant son archivage dans le
 * stockage objet, afin d'y réduire l'empreinte des scans et photos volumineux.
 *
 * <p>La compression ne concerne que la <b>copie archivée</b> : l'extraction
 * (OCR) doit toujours s'appuyer sur les octets d'origine. Un document déjà léger
 * ou non compressible est renvoyé inchangé.</p>
 */
public interface DocumentCompressorPort {

    /** Résultat : octets (compressés ou d'origine) et leur type MIME. */
    record DocumentCompresse(byte[] octets, String contentType) {}

    /**
     * @param octets       contenu original du document (PDF ou image)
     * @param contentType  type MIME d'origine (peut être {@code null})
     * @return le document compressé, ou l'original si la compression n'apporte rien
     */
    DocumentCompresse compresser(byte[] octets, String contentType);
}
