package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

/**
 * Tient l'historique des vidanges à jour au rythme des maintenances « Vidange ».
 * <p>
 * Clôturer l'intervention enregistre la vidange faite : sans elle, la cible de
 * la vidange précédente restait la « prochaine », et l'état de parc continuait
 * de réclamer une vidange déjà faite. Défaire la complétion (la maintenance
 * repasse planifiée) retire la ligne : la vidange n'a pas eu lieu.
 * <p>
 * La prochaine cible reprend le rythme de la vidange précédente — même écart
 * en jours, même écart en kilomètres. Sans précédent pour le donner, la ligne
 * n'a pas de cible : le gestionnaire la fixe en saisissant la suivante.
 */
@RequiredArgsConstructor
public class VidangeMaintenanceService {

    private final VidangeRepository vidangeRepository;

    /**
     * Enregistre la vidange faite par cette maintenance terminée. Sans effet si
     * l'intervention n'est pas une vidange, si elle en a déjà produit une, ou si
     * aucun kilométrage ne la situe (relevé à l'intervention, à défaut compteur
     * du véhicule) : une vidange sans kilométrage ne servirait aucune alerte.
     */
    public void enregistrerVidangeFaite(Maintenance maintenance) {
        if (!maintenance.estVidange() || maintenance.getVehicule() == null
                || maintenance.getVehicule().getId() == null
                || maintenance.getDateEffectuee() == null) {
            return;
        }
        if (vidangeRepository.findByMaintenanceId(maintenance.getId()).isPresent()) {
            return;
        }
        Integer kilometrage = maintenance.getKilometrageAuMoment() != null
                ? maintenance.getKilometrageAuMoment()
                : maintenance.getVehicule().getKilometrage();
        if (kilometrage == null) {
            return;
        }

        Long vehiculeId = maintenance.getVehicule().getId();
        LocalDate date = maintenance.getDateEffectuee();
        Vidange precedente = vidangeRepository.findDerniereByVehiculeId(vehiculeId).orElse(null);

        Vidange vidange = Vidange.builder()
                .vehiculeId(vehiculeId)
                .dateVidange(date)
                .kilometrageVidange(kilometrage)
                .dateProchaineVidange(prochaineDate(precedente, date))
                .kilometrageProchaineVidange(prochainKilometrage(precedente, kilometrage))
                .commentaire("Enregistrée à la clôture de la maintenance.")
                .maintenanceId(maintenance.getId())
                .build();
        vidange.valider();
        vidangeRepository.save(vidange);
    }

    /** Retire la vidange produite par cette maintenance, dont la complétion est défaite. */
    public void retirerVidangeFaite(Maintenance maintenance) {
        if (maintenance.getId() == null) return;
        vidangeRepository.findByMaintenanceId(maintenance.getId())
                .ifPresent(v -> vidangeRepository.deleteById(v.getId()));
    }

    private static LocalDate prochaineDate(Vidange precedente, LocalDate date) {
        if (precedente == null || precedente.getDateProchaineVidange() == null
                || precedente.getDateVidange() == null) {
            return null;
        }
        long jours = ChronoUnit.DAYS.between(precedente.getDateVidange(),
                precedente.getDateProchaineVidange());
        return jours > 0 ? date.plusDays(jours) : null;
    }

    private static Integer prochainKilometrage(Vidange precedente, int kilometrage) {
        if (precedente == null || precedente.getKilometrageProchaineVidange() == null
                || precedente.getKilometrageVidange() == null) {
            return null;
        }
        int ecart = precedente.getKilometrageProchaineVidange() - precedente.getKilometrageVidange();
        return ecart > 0 ? kilometrage + ecart : null;
    }
}
