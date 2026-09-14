package com.tmk.vtc_manager

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/**
 * Partage d'un reçu PDF, avec son message, dans la conversation WhatsApp du
 * chauffeur.
 *
 * Le lien wa.me ne transporte que du texte : une pièce jointe passe forcément
 * par une intention ACTION_SEND. Adressée au paquet de WhatsApp avec l'extra
 * `jid`, elle ouvre directement la conversation du numéro, fichier et message
 * prêts à partir. Cet extra n'est pas documenté par WhatsApp : s'il venait à
 * être ignoré, WhatsApp s'ouvrirait sur son choix de contact — le reçu reste
 * joint, seul le destinataire est à désigner.
 *
 * Sans WhatsApp ni WhatsApp Business, la feuille de partage d'Android prend le
 * relais : le reçu peut partir par un autre moyen.
 */
object PartageRecu {

    const val CHANNEL = "vtc/partage"

    /** WhatsApp d'abord, WhatsApp Business ensuite : le gestionnaire peut avoir les deux. */
    private val PAQUETS_WHATSAPP = listOf("com.whatsapp", "com.whatsapp.w4b")

    /** Les reçus servent le temps d'un envoi : au-delà d'un jour, ils encombrent le cache. */
    private const val DUREE_CONSERVATION_MS = 24L * 60 * 60 * 1000

    /**
     * @param telephone numéro international en chiffres (2250712345678), ou nul
     * @return "WHATSAPP" si WhatsApp s'est ouvert, "PARTAGE" pour la feuille de partage
     */
    fun partager(
        activity: Activity,
        nomFichier: String,
        octets: ByteArray,
        mime: String,
        telephone: String?,
        texte: String?,
    ): String {
        val dossier = File(activity.cacheDir, "recus").apply { mkdirs() }
        purger(dossier)
        val fichier = File(dossier, nomFichier).apply { writeBytes(octets) }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.recus", fichier)

        for (paquet in PAQUETS_WHATSAPP) {
            val versWhatsApp = intention(uri, mime, texte).apply {
                setPackage(paquet)
                if (!telephone.isNullOrBlank()) putExtra("jid", "$telephone@s.whatsapp.net")
            }
            try {
                activity.startActivity(versWhatsApp)
                return "WHATSAPP"
            } catch (_: ActivityNotFoundException) {
                // Ce paquet n'est pas installé : on tente le suivant.
            }
        }

        activity.startActivity(Intent.createChooser(intention(uri, mime, texte), "Envoyer le reçu"))
        return "PARTAGE"
    }

    private fun intention(uri: Uri, mime: String, texte: String?) = Intent(Intent.ACTION_SEND).apply {
        type = mime
        putExtra(Intent.EXTRA_STREAM, uri)
        if (!texte.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, texte)
        // Le ClipData porte l'autorisation de lecture jusqu'à l'application
        // choisie, y compris à travers la feuille de partage.
        clipData = ClipData.newRawUri("", uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    private fun purger(dossier: File) {
        val limite = System.currentTimeMillis() - DUREE_CONSERVATION_MS
        dossier.listFiles()?.filter { it.lastModified() < limite }?.forEach { it.delete() }
    }
}
