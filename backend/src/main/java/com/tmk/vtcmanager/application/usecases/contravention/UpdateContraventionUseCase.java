package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.StatutRattachement;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class UpdateContraventionUseCase {

    private final ContraventionRepository contraventionRepository;

    @Transactional
    public Contravention execute(Long id, Contravention data) {
        Contravention existing = contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));

        // Rattachement chauffeur/véhicule avant écrasement, pour détecter un
        // changement manuel du lien effectué par l'exploitant.
        Long ancienChauffeurId = existing.getChauffeur() != null ? existing.getChauffeur().getId() : null;
        StatutRattachement ancienStatut = existing.getStatutRattachement();

        existing.setDateInfraction(data.getDateInfraction());
        existing.setTypeInfraction(data.getTypeInfraction());
        existing.setLieu(data.getLieu());
        existing.setDescription(data.getDescription());
        existing.setMontant(data.getMontant());
        existing.setCotisation(data.getCotisation());
        if (data.getMontantPaye() != null) existing.setMontantPaye(data.getMontantPaye());
        if (data.getStatut() != null) existing.setStatut(data.getStatut());
        existing.setDatePaiement(data.getDatePaiement());
        existing.setChauffeur(data.getChauffeur());
        existing.setVehicule(data.getVehicule());

        // Recalcule l'état du rattachement selon le lien saisi :
        //  • aucun chauffeur → A_RATTACHER ;
        //  • chauffeur nouvellement affecté (ou lien qui était « à rattacher »)
        //    → MANUEL (rattachement décidé par l'exploitant) ;
        //  • même chauffeur qu'avant → statut conservé (AUTO/MANUEL préservé).
        Long nouveauChauffeurId = data.getChauffeur() != null ? data.getChauffeur().getId() : null;
        if (nouveauChauffeurId == null) {
            existing.setStatutRattachement(StatutRattachement.A_RATTACHER);
        } else if (ancienStatut == null
                || ancienStatut == StatutRattachement.A_RATTACHER
                || !nouveauChauffeurId.equals(ancienChauffeurId)) {
            existing.setStatutRattachement(StatutRattachement.MANUEL);
        }

        return contraventionRepository.save(existing);
    }
}
