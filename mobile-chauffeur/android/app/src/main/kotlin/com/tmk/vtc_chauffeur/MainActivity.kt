package com.tmk.vtc_chauffeur

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * FlutterFragmentActivity et non FlutterActivity : le déverrouillage
 * biométrique (local_auth) s'appuie sur androidx.biometric.BiometricPrompt,
 * qui a besoin d'une FragmentActivity pour s'afficher.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Avant toute notification : une notification dont le canal n'existe
        // pas encore est reçue mais reste silencieuse.
        NotificationChannels.creer(applicationContext)

        // Verrouillage de l'appareil → verrouillage de l'application.
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DeviceLockStreamHandler.CHANNEL,
        ).setStreamHandler(DeviceLockStreamHandler(applicationContext))
    }
}
