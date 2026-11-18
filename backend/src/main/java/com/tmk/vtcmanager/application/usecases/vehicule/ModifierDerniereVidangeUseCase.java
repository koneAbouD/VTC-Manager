package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Corrige la dernière vidange saisie d'un véhicule (date, kilométrage, cible).
 * <p>
 * Seule la plus récente est modifiable : c'est elle qui porte la « prochaine
 * vidange » lue par l'état de parc et les rappels ; les lignes plus anciennes
 * sont de l'historique figé. La correction ne peut pas la faire passer avant la
 * vidange précédente (date ou kilométrage), sinon elle cesserait d'être la
 * dernière et l'ancienne cible redeviendrait silencieusement la prochaine.
 * Le lien éventuel vers la maintenance d'origine est conservé.
 */
@RequiredArgsConstructor
public class ModifierDerniereVidangeUseCase {

    private final VidangeRepository vidangeRepository;
    private final VehiculeRepository vehiculeRepository;

    @Transactional
    public Vidange execute(Long vehiculeId, Long vidangeId, Vidange correction) {
        vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        List<Vidange> historique = vidangeRepository.findByVehiculeId(vehiculeId);
        Vidange derniere = historique.isEmpty() ? null : historique.get(0);
        if (derniere == null || !derniere.getId().equals(vidangeId)) {
            if (historique.stream().noneMatch(v -> v.getId().equals(vidangeId))) {
                throw ResourceNotFoundException.of("Vidange", vidangeId);
            }
            throw new IllegalStateException("Seule la dernière vidange saisie peut être modifiée.");
        }

        derniere.setDateVidange(correction.getDateVidange());
        derniere.setKilometrageVidange(correction.getKilometrageVidange());
        derniere.setDateProchaineVidange(correction.getDateProchaineVidange());
        derniere.setKilometrageProchaineVidange(correction.getKilometrageProchaineVidange());
        derniere.setCommentaire(correction.getCommentaire());
        derniere.valider();

        if (historique.size() > 1) {
            Vidange precedente = historique.get(1);
            if (derniere.getDateVidange().isBefore(precedente.getDateVidange())) {
                throw new IllegalArgumentException(
                        "La date ne peut pas être antérieure à celle de la vidange précédente.");
            }
            if (derniere.getKilometrageVidange() < precedente.getKilometrageVidange()) {
                throw new IllegalArgumentException(
                        "Le kilométrage ne peut pas être inférieur à celui de la vidange précédente.");
            }
        }
        return vidangeRepository.save(derniere);
    }
}
