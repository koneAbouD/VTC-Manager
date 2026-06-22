package com.tmk.vtcmanager.application.ports.storage;

import java.io.InputStream;

public interface FileStoragePort {

    /** Envoie un fichier et retourne son URL d'accès. */
    String upload(String objectName, InputStream content, long size, String contentType);

    /** Retourne un flux de lecture du fichier. */
    InputStream download(String objectName);

    /** Supprime le fichier du stockage. */
    void delete(String objectName);

    /** Copie un objet vers un autre chemin dans le même bucket. */
    void copy(String source, String destination);

    /** Génère une URL présignée temporaire (lecture). */
    String presignedUrl(String objectName, int expirySeconds);
}