package com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@RequiredArgsConstructor
public class UpdateIndisponibiliteVehiculeUseCase {

    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final VehiculeStatutEventPublisher vehiculeStatutEventPublisher;

    @Transactional
    public IndisponibiliteVehicule execute(Long id, IndisponibiliteVehicule data) {
        IndisponibiliteVehicule existing = indisponibiliteVehiculeRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité véhicule", id));
        final Long ancienVehiculeId = existing.getVehiculeId();

        if (existing.getStatut() == IndisponibiliteStatut.TERMINEE
                || existing.getStatut() == IndisponibiliteStatut.ANNULEE) {
            throw new IllegalArgumentException(
                    "Une indisponibilité terminée ou annulée ne peut pas être modifiée.");
        }
        if (data.getVehicule() == null || data.getVehicule().getId() == null) {
            throw new IllegalArgumentException(
                    "Un véhicule est obligatoire pour une indisponibilité véhicule.");
        }
        data.validerCoherence();

        // ── Protection des jours passés ────────────────────────────────────
        // On ne réécrit jamais la partie déjà écoulée d'une immobilisation.
        final LocalDate today = LocalDate.now();
        final boolean dejaDemarree = existing.getDateDebut() != null
                && !existing.getDateDebut().isAfter(today);
        if (dejaDemarree) {
            // En cours : la date de début reste celle d'origine (jours passés
            // intouchés) et la date de fin ne peut pas repasser avant aujourd'hui.
            data.setDateDebut(existing.getDateDebut());
            if (data.getDateFin() != null && data.getDateFin().isBefore(today)) {
                throw new IllegalArgumentException(
                        "La date de fin ne peut pas être antérieure à aujourd'hui "
                                + "pour une immobilisation en cours.");
            }
        } else if (data.getDateDebut() != null && data.getDateDebut().isBefore(today)) {
            // Planifiée : interdiction de la déplacer sur une date passée.
            throw new IllegalArgumentException(
                    "L'immobilisation ne peut pas être déplacée sur une date passée.");
        }
        data.validerCoherence();

        existing.setVehicule(data.getVehicule());
        existing.setDateDebut(data.getDateDebut());
        existing.setDateFin(data.getDateFin());
        existing.setMotif(data.getMotif());
        existing.setCommentaire(data.getCommentaire());
        existing.setStatut(data.getStatut() != null
                ? data.getStatut()
                : existing.computeStatutFromDates());

        IndisponibiliteVehicule saved = indisponibiliteVehiculeRepository.save(existing);

        // Recalcul du statut pour l'ancien et le nouveau véhicule (la période ou
        // le véhicule ont pu changer).
        vehiculeStatutEventPublisher.publishStatutDirty(ancienVehiculeId);
        Long nouveauVehiculeId = saved.getVehiculeId();
        if (nouveauVehiculeId != null && !nouveauVehiculeId.equals(ancienVehiculeId)) {
            vehiculeStatutEventPublisher.publishStatutDirty(nouveauVehiculeId);
        }
        return saved;
    }
}
