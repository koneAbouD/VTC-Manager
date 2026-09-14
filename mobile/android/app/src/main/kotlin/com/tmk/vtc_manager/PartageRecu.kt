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
 * Partage d'un reçu PDF, message en légende, quand le chauffeur n'a pas de
 * numéro : le contact est de toute façon à choisir dans WhatsApp, autant que le
 * reçu y arrive déjà joint.
 *
 * Avec un numéro, l'application ne passe pas par ici : elle enregistre le PDF
 * et ouvre la conversation par le lien wa.me, seul chemin qui mène sûrement au
 * bon chauffeur. WhatsApp 2.26 ignore en effet tout destinataire joint à une
 * intention ACTION_SEND — l'extra `jid` comme l'identifiant de raccourci de
 * partage : sur un appareil réel, l'écran « Envoyer à… » s'ouvrait à chaque fois.
 *
 * Sans WhatsApp ni WhatsApp Business, la feuille de partage d'Android prend le
 * relais.
 */
object PartageRecu {

    const val CHANNEL = "vtc/partage"

    private const val TAG = "VtcPartage"

    /** WhatsApp d'abord, WhatsApp Business ensuite : le gestionnaire peut avoir les deux. */
    private val PAQUETS_WHATSAPP = listOf("com.whatsapp", "com.whatsapp.w4b")

    /** Les reçus servent le temps d'un envoi : au-delà d'un jour, ils encombrent le cache. */
    private const val DUREE_CONSERVATION_MS = 24L * 60 * 60 * 1000

    /** @return "WHATSAPP" si WhatsApp s'est ouvert, "PARTAGE" pour la feuille de partage */
    fun partager(
        activity: Activity,
        nomFichier: String,
        octets: ByteArray,
        mime: String,
        texte: String?,
    ): String {
        val dossier = File(activity.cacheDir, "recus").apply { mkdirs() }
        purger(dossier)
        val fichier = File(dossier, nomFichier).apply { writeBytes(octets) }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.recus", fichier)

        for (paquet in PAQUETS_WHATSAPP) {
            try {
                activity.startActivity(intention(uri, mime, texte).apply { setPackage(paquet) })
                Log.i(TAG, "Reçu joint et adressé à $paquet, contact à choisir")
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
