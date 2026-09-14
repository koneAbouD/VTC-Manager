package com.tmk.vtcmanager.interfaces.rest.arrete.dto.response;

/** Chauffeur concerné par un arrêté, avec son téléphone : un destinataire du décompte. */
public record ChauffeurArreteResponse(Long id, String nom, String telephone) {
}
