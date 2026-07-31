package com.tmk.vtc_chauffeur

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.EventChannel

/**
 * Signale à Flutter que l'appareil a été verrouillé, pour que l'application se
 * remette elle aussi sous clé.
 *
 * On suit le keyguard, pas l'écran : Android laisse un délai réglable entre
 * l'extinction et le verrouillage (« Verrouiller après extinction de l'écran »),
 * pendant lequel l'appareil n'est pas verrouillé — l'application n'a donc pas à
 * l'être. Deux signaux y suffisent, sans sondage :
 *
 *  • ACTION_SCREEN_OFF, à condition que le keyguard soit déjà armé — c'est le
 *    cas du verrouillage immédiat, le réglage le plus courant ;
 *  • ACTION_USER_PRESENT, qui vaut constat rétroactif : si l'utilisateur vient
 *    de déverrouiller, c'est que l'appareil était verrouillé. Ce second signal
 *    rattrape les verrouillages différés, survenus alors que l'application ne
 *    recevait plus rien, et il arrive toujours avant qu'elle ne revienne à
 *    l'écran — on ne peut pas retrouver l'application ouverte sans passer par
 *    le keyguard.
 *
 * Le tout filtré par isDeviceSecure : sans code, schéma ni empreinte sur le
 * téléphone, il n'y a pas de verrouillage à suivre, et l'application n'a pas à
 * se montrer plus stricte que l'appareil qui l'héberge.
 */
class DeviceLockStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        const val CHANNEL = "vtc/device_lock"
    }

    private var receiver: BroadcastReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

        val nouveau = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (!keyguard.isDeviceSecure) return
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF ->
                        if (keyguard.isKeyguardLocked) events?.success("locked")
                    Intent.ACTION_USER_PRESENT -> events?.success("locked")
                }
            }
        }
        receiver = nouveau

        val filtre = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        // Broadcasts protégés du système : le receiver n'a aucune raison d'être
        // exposé aux autres applications.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(nouveau, filtre, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(nouveau, filtre)
        }
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
    }
}
