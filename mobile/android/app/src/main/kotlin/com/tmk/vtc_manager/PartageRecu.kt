package com.tmk.vtc_manager

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

/**
 * Partage d'un reçu PDF, avec son message, dans la conversation WhatsApp du
 * chauffeur.
 *
 * Le lien wa.me ne transporte que du texte : une pièce jointe passe forcément
 * par une intention ACTION_SEND, que WhatsApp reçoit dans son écran de partage
 * (`ExternalShareAlias`). Seul, cet écran demande le contact.
 *
 * Pour aller droit à la conversation, l'intention porte l'identifiant de
 * raccourci de partage (`android.intent.extra.shortcut.ID`) : c'est ce que le
 * système transmet quand on touche une conversation dans la feuille de partage,
 * et WhatsApp publie ses raccourcis sous l'identifiant `numéro@s.whatsapp.net`.
 * L'ancien extra `jid` est conservé pour les versions qui le lisent encore —
 * WhatsApp 2.26 l'ignore, les journaux d'un appareil l'ont montré. Si aucun des
 * deux n'est lu, WhatsApp retombe sur son choix de contact : le reçu reste
 * joint, seul le destinataire est à désigner.
 *
 * Sans WhatsApp ni WhatsApp Business, la feuille de partage d'Android prend le
 * relais : le reçu peut partir par un autre moyen.
 */
object PartageRecu {

    const val CHANNEL = "vtc/partage"

    /** WhatsApp d'abord, WhatsApp Business ensuite : le gestionnaire peut avoir les deux. */
    private val PAQUETS_WHATSAPP = listOf("com.whatsapp", "com.whatsapp.w4b")

    private const val TAG = "VtcPartage"

    /**
     * `Intent.EXTRA_SHORTCUT_ID`, écrit en toutes lettres : la constante n'existe
     * qu'à partir d'Android 10, la valeur est lue par WhatsApp sur toutes versions.
     */
    private const val EXTRA_RACCOURCI_PARTAGE = "android.intent.extra.shortcut.ID"

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

        val destinataire = if (telephone.isNullOrBlank()) null else "$telephone@s.whatsapp.net"

        for (paquet in PAQUETS_WHATSAPP) {
            val versWhatsApp = intention(uri, mime, texte).apply {
                setPackage(paquet)
                if (destinataire != null) {
                    putExtra(EXTRA_RACCOURCI_PARTAGE, destinataire)
                    putExtra("jid", destinataire)
                }
            }
            try {
                activity.startActivity(versWhatsApp)
                // Jamais le numéro dans les journaux : seulement ce qui a été tenté.
                Log.i(TAG, "Reçu adressé à $paquet, destinataire ${if (destinataire != null) "désigné" else "à choisir"}")
                return "WHATSAPP"
            } catch (_: ActivityNotFoundException) {
                // Ce paquet n'est pas installé : on tente le suivant.
            }
        }

        Log.i(TAG, "WhatsApp absent : feuille de partage du système")
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
