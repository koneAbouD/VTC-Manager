package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeStatutHistoriqueRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDateTime;

/**
 * Historise les transitions de statut d'un véhicule : clôt la période en cours
 * et en ouvre une nouvelle. Appelé par les use cases qui changent effectivement
 * le statut (recalcul automatique, saisie manuelle, création) — dans la même
 * transaction, donc annulé avec elle en cas d'échec.
 * <p>
 * Idempotent sur le statut : si la période en cours porte déjà le statut
 * demandé, seule la mise à jour du motif est appliquée (pas de nouvelle ligne).
 */
@RequiredArgsConstructor
public class VehiculeStatutHistoriqueService {

    private final VehiculeStatutHistoriqueRepository historiqueRepository;

    public void enregistrerTransition(Long vehiculeId, VehiculeStatus statut, VehiculeStatutMotif motif) {
        if (vehiculeId == null || statut == null) return;

        LocalDateTime maintenant = LocalDateTime.now();
        var enCours = historiqueRepository.findEnCoursByVehiculeId(vehiculeId);

        if (enCours.isPresent()) {
            VehiculeStatutHistorique periode = enCours.get();
            if (periode.getStatut() == statut) {
                if (motif != null && periode.getMotif() != motif) {
                    periode.setMotif(motif);
                    historiqueRepository.save(periode);
                }
                return;
            }
            periode.clore(maintenant);
            historiqueRepository.save(periode);
        }

        historiqueRepository.save(VehiculeStatutHistorique.builder()
                .vehiculeId(vehiculeId)
                .statut(statut)
                .motif(motif)
                .dateDebut(maintenant)
                .build());
    }
}
