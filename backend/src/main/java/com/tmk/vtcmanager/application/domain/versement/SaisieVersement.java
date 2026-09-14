package com.tmk.vtcmanager.application.domain.versement;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.time.LocalDate;

/**
 * Un billet remis au guichet, et ce qu'il solde : la recette du jour, sa
 * cotisation, ou les deux. Le mode, la date, la référence et le commentaire
 * valent pour tout le versement — c'est le même argent.
 *
 * <p>Une part absente vaut « rien pour cette créance ». Il en faut au moins une.
 */
public record SaisieVersement(
        PartVersement recette,
        PartVersement cotisation,
        ModePaiement mode,
        LocalDate date,
        String reference,
        String commentaire
) {}
