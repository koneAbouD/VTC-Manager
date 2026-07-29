package com.tmk.vtc_chauffeur

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity et non FlutterActivity : le déverrouillage
 * biométrique (local_auth) s'appuie sur androidx.biometric.BiometricPrompt,
 * qui a besoin d'une FragmentActivity pour s'afficher.
 */
class MainActivity : FlutterFragmentActivity()
