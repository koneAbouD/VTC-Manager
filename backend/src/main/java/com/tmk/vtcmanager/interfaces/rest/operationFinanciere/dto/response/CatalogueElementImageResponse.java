package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

/**
 * Réponse de l'upload d'une image d'élément de maintenance.
 *
 * @param image nom d'objet à renvoyer dans la requête de création / mise à jour
 * @param url   URL présignée temporaire pour l'aperçu immédiat côté client
 */
public record CatalogueElementImageResponse(String image, String url) {}
