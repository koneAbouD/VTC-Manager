package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.ModificationEcritureGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Modification d'une écriture existante.
 *
 * <p>Deux familles n'y ont pas droit du tout : les encaissements (recette,
 * cotisation, pénalité, contravention) et les dépenses issues d'une
 * complétion de maintenance. Leur montant appartient à la ligne ou à
 * l'intervention qui les a produites ; le corriger ici les désaccorderait en
 * silence. Pour ces écritures, la voie est l'annulation — qui repositionne la
 * source à son état antérieur — puis la ressaisie depuis le module d'origine.
 *
 * <p>Pour les autres, ce qui reste modifiable dépend de l'état des livres :
 * voir {@link ModificationEcritureGuard}. Pour corriger un montant figé, la
 * voie est l'extourne puis la ressaisie — elle laisse une trace.
 */
@RequiredArgsConstructor
public class UpdateOperationFinanciereUseCase {

    private final OperationFinanciereRepository operationRepository;
    private final ModificationEcritureGuard modificationEcritureGuard;

    @Transactional
    public OperationFinanciere execute(Long id, OperationFinanciere data) {
        OperationFinanciere existing = operationRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Opération", id));

        if (existing.getStatut() == StatutOperation.ANNULEE) {
            throw new IllegalStateException("Impossible de modifier une opération annulée.");
        }

        if (existing.estUnEncaissement()) {
            throw new EcritureFigeeException("Un encaissement ne se modifie pas : son montant est"
                    + " celui du versement enregistré sur la créance. Annulez-le — la créance"
                    + " redevient due — puis ressaisissez l'encaissement.");
        }
        if (existing.estIssueDUneMaintenance()) {
            throw new EcritureFigeeException("Cette dépense provient d'une maintenance : elle ne se"
                    + " modifie pas ici. Annulez-la — la maintenance repasse en planifiée — puis"
                    + " terminez-la de nouveau avec les bonnes valeurs.");
        }

        // Période close, caisse comptée, écriture déjà extournée : le garde-fou
        // dit ce qui est encore permis, en comparant l'avant et l'après.
        modificationEcritureGuard.verifier(existing, data);

        existing.setTypeOperation(data.getTypeOperation());
        existing.setCategorie(data.getCategorie());
        existing.setSousCategorie(data.getSousCategorie());
        existing.setChauffeur(data.getChauffeur());
        existing.setVehicule(data.getVehicule());
        existing.setPartenaire(data.getPartenaire());
        existing.setModePaiement(data.getModePaiement());
        existing.setDateOperation(data.getDateOperation());
        existing.setCommentaire(data.getCommentaire());
        existing.setDetailMaintenance(data.getDetailMaintenance());

        // Recalcul montant si maintenance
        if (data.getDetailMaintenance() != null
                && data.getDetailMaintenance().getElements() != null
                && !data.getDetailMaintenance().getElements().isEmpty()) {
            var total = data.getDetailMaintenance().getElements().stream()
                    .map(e -> e.getMontant() != null ? e.getMontant() : java.math.BigDecimal.ZERO)
                    .reduce(java.math.BigDecimal.ZERO, java.math.BigDecimal::add);
            existing.setMontant(total);
        } else {
            existing.setMontant(data.getMontant());
        }

        return operationRepository.save(existing);
    }
}
