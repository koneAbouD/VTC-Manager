package com.tmk.vtc_manager

import androidx.core.content.FileProvider

/**
 * Fournisseur des reçus partagés vers WhatsApp.
 *
 * Une sous-classe plutôt que FileProvider nu : si une bibliothèque déclare déjà
 * `androidx.core.content.FileProvider` dans son manifeste, deux déclarations de
 * la même classe font échouer la fusion des manifestes.
 */
class RecusFileProvider : FileProvider()
