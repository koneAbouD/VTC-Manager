package com.tmk.vtcmanager.interfaces.rest.common;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

/**
 * Corps de requête d'une correction de date de versement.
 *
 * <p>Rien d'autre à porter : le montant, le mode et la caisse ne bougent pas —
 * seul le jour où l'argent est réputé entré se déplace. L'auteur de la
 * correction est enregistré par l'audit des écritures, sans qu'on ait à le
 * demander.
 */
public record ModificationDateEncaissementRequest(
        @NotNull(message = "La date d'encaissement est obligatoire.") LocalDate dateEncaissement
) {}
