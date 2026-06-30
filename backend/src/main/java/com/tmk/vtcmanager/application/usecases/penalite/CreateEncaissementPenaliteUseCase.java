package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.exception.EncaissementPenaliteDepasseMontantException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonEncaissableException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@RequiredArgsConstructor
public class CreateEncaissementPenaliteUseCase {

    private static final String CODE_CATEGORIE = "ENCAISSEMENT_PENALITES";

    private final LignePenaliteRepository lignePenaliteRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;

    @Transactional
    public EncaissementPenalite executer(Long lignePenaliteId, EncaissementPenalite encaissement) {
        LignePenalite ligne = lignePenaliteRepository.findById(lignePenaliteId)
                .orElseThrow(() -> new LignePenaliteNotFoundException(lignePenaliteId));

        if (!ligne.isEncaissable()) {
            throw new LignePenaliteNonEncaissableException(lignePenaliteId);
        }

        if (encaissement.getMontant().compareTo(ligne.montantRestant()) > 0) {
            throw new EncaissementPenaliteDepasseMontantException(ligne.montantRestant());
        }

        encaissement.setLignePenaliteId(lignePenaliteId);

        OperationFinanciere operation = creerOperation(ligne, encaissement);
        encaissement.setOperationFinanciereId(operation.getId());

        EncaissementPenalite saved = encaissementPenaliteRepository.save(encaissement);

        LignePenalite ligneComplete = lignePenaliteRepository.findById(lignePenaliteId).orElseThrow();
        ligneComplete.getEncaissements().add(saved);
        ligneComplete.recalculerStatutAmende();
        lignePenaliteRepository.updateStatutAndMontantEncaisse(
                lignePenaliteId,
                ligneComplete.getStatut(),
                ligneComplete.getMontantEncaisse());

        return saved;
    }

    private OperationFinanciere creerOperation(LignePenalite ligne, EncaissementPenalite encaissement) {
        CategorieOperation categorie = categorieOperationRepository.findByCode(CODE_CATEGORIE).orElse(null);

        com.tmk.vtcmanager.application.domain.vehicule.Vehicule vehicule =
                new com.tmk.vtcmanager.application.domain.vehicule.Vehicule();
        vehicule.setId(ligne.getVehiculeId());

        com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur chauffeur =
                new com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur();
        chauffeur.setId(ligne.getChauffeurId());

        OperationFinanciere op = OperationFinanciere.builder()
                .typeOperation(TypeOperation.REVENU)
                .categorie(categorie)
                .vehicule(vehicule)
                .chauffeur(chauffeur)
                .montant(encaissement.getMontant())
                .modePaiement(encaissement.getModeEncaissement())
                .dateOperation(encaissement.getDateEncaissement())
                .dateReference(ligne.getDateFaute())
                .commentaire(encaissement.getCommentaire())
                .reference(genererReference())
                .statut(StatutOperation.VALIDEE)
                .build();

        return operationFinanciereRepository.save(op);
    }

    private String genererReference() {
        String ts = String.valueOf(System.currentTimeMillis()).substring(7);
        return "PEN-" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy")) + "-" + ts;
    }
}
