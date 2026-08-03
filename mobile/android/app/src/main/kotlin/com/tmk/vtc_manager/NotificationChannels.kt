package com.tmk.vtc_manager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * Canal de notification de l'application.
 *
 * Depuis Android 8, toute notification appartient à un canal, et un canal
 * inconnu la prive de son son et de sa priorité — sans erreur, ni côté serveur
 * ni côté appareil. Le créer ici plutôt que de laisser Firebase s'en charger
 * permet de maîtriser ce que l'utilisateur lit dans les réglages du système :
 * « Alertes TMK », et non un intitulé technique.
 *
 * L'identifiant doit rester identique à `FcmPushAdapter.CANAL_ANDROID` côté
 * backend, à `PushService.canalAndroid` côté Dart et au `meta-data` du
 * manifeste. Le modifier après une première installation est sans effet :
 * Android ignore la redéfinition d'un canal existant, seule une désinstallation
 * le recrée.
 */
object NotificationChannels {

    const val DEFAUT = "vtc_notifications_default"

    fun creer(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val canal = NotificationChannel(
            DEFAUT,
            "Alertes TMK",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Maintenances, immobilisations et alertes de gestion."
        }

        context.getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(canal)
    }
}
