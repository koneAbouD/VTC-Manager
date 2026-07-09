package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ResultatImportContraventions;
import com.tmk.vtcmanager.application.domain.contravention.StatutRattachement;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Persiste les contraventions révisées par l'exploitant (réutilise le cycle de
 * vie de paiement/reversement existant). Idempotent : un numéro déjà présent est
 * ignoré (relevés cumulatifs).
 */
@RequiredArgsConstructor
public class ConfirmerImportContraventionsUseCase {

    private final ContraventionRepository contraventionRepository;

    @Transactional
    public ResultatImportContraventions confirmer(List<Contravention> validees) {
        int creees = 0;
        int rattachees = 0;
        int doublons = 0;

        for (Contravention c : validees) {
            if (c.getNumeroContravention() != null
                    && contraventionRepository.existsByNumero(c.getNumeroContravention())) {
                doublons++;
                continue;
            }

            boolean rattachee = c.getChauffeur() != null && c.getChauffeur().getId() != null;
            if (rattachee) {
                if (c.getStatutRattachement() == null
                        || c.getStatutRattachement() == StatutRattachement.A_RATTACHER) {
                    c.setStatutRattachement(StatutRattachement.MANUEL);
                }
                rattachees++;
            } else {
                c.setStatutRattachement(StatutRattachement.A_RATTACHER);
            }

            c.setId(null); // création
            c.initializeDefaults();
            contraventionRepository.save(c);
            creees++;
        }
        return new ResultatImportContraventions(creees, rattachees, doublons);
    }
}
