package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.AucunePenaliteAmendePendingException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeOuChauffeurSansLigneActiveException;
import com.tmk.vtcmanager.application.exception.VehiculeOuChauffeurSansLigneCotisationActiveException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@RequiredArgsConstructor
public class CreateOperationFinanciereUseCase {

    private static final String CODE_ENCAISSEMENT_RECETTES   = "ENCAISSEMENT_RECETTES";
    private static final String CODE_ENCAISSEMENT_COTISATION  = "ENCAISSEMENT_COTISATIONS";
    private static final String CODE_ENCAISSEMENT_PENALITES   = "ENCAISSEMENT_PENALITES";

    private final OperationFinanciereRepository operationRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final VehiculeRepository vehiculeRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LignePenaliteRepository lignePenaliteRepository;

    @Transactional
    public OperationFinanciere execute(OperationFinanciere operation) {
        // Validation chauffeur
        if (operation.getChauffeur() != null && operation.getChauffeur().getId() != null) {
            chauffeurRepository.findById(operation.getChauffeur().getId())
                    .orElseThrow(() -> ResourceNotFoundException.of("Chauffeur", operation.getChauffeur().getId()));
        }

        // Validation véhicule si fourni
        if (operation.getVehicule() != null && operation.getVehicule().getId() != null) {
            vehiculeRepository.findById(operation.getVehicule().getId())
                    .orElseThrow(() -> ResourceNotFoundException.of("Véhicule", operation.getVehicule().getId()));
        }

        // Garde : encaissement de recette exige une ligne active
        if (operation.getCategorie() != null
                && CODE_ENCAISSEMENT_RECETTES.equals(operation.getCategorie().getCode())) {
            validerLigneRecetteActive(operation);
        }

        // Garde : encaissement de cotisation exige une ligne active
        if (operation.getCategorie() != null
                && CODE_ENCAISSEMENT_COTISATION.equals(operation.getCategorie().getCode())) {
            validerLigneCotisationActive(operation);
        }

        // Garde : encaissement pénalités exige une pénalité AMENDE en attente
        if (operation.getCategorie() != null
                && CODE_ENCAISSEMENT_PENALITES.equals(operation.getCategorie().getCode())) {
            validerPenaliteAmendePending(operation);
        }

        // Calcul automatique du montant pour les opérations de maintenance
        if (operation.getDetailMaintenance() != null
                && operation.getDetailMaintenance().getElements() != null
                && !operation.getDetailMaintenance().getElements().isEmpty()) {
            var total = operation.getDetailMaintenance().getElements().stream()
                    .map(e -> e.getMontant() != null ? e.getMontant() : java.math.BigDecimal.ZERO)
                    .reduce(java.math.BigDecimal.ZERO, java.math.BigDecimal::add);
            operation.setMontant(total);
        }

        // Génération de la référence
        operation.setReference(generateReference(operation.getTypeOperation()));

        // Statut par défaut
        if (operation.getStatut() == null) {
            operation.setStatut(StatutOperation.BROUILLON);
        }

        return operationRepository.save(operation);
    }

    private void validerLigneRecetteActive(OperationFinanciere operation) {
        LocalDate date = operation.getDateOperation() != null ? operation.getDateOperation() : LocalDate.now();
        boolean ligneActive = false;

        if (operation.getVehicule() != null && operation.getVehicule().getId() != null) {
            ligneActive = ligneRecetteRepository
                    .findActiveByVehiculeIdAndDate(operation.getVehicule().getId(), date)
                    .isPresent();
        }
        if (!ligneActive && operation.getChauffeur() != null && operation.getChauffeur().getId() != null) {
            ligneActive = ligneRecetteRepository
                    .findActiveByChauffeurIdAndDate(operation.getChauffeur().getId(), date)
                    .isPresent();
        }
        if (!ligneActive) {
            throw new VehiculeOuChauffeurSansLigneActiveException();
        }
    }

    private void validerLigneCotisationActive(OperationFinanciere operation) {
        LocalDate date = operation.getDateOperation() != null ? operation.getDateOperation() : LocalDate.now();
        boolean ligneActive = false;
        if (operation.getVehicule() != null && operation.getVehicule().getId() != null) {
            ligneActive = ligneCotisationRepository
                    .findActiveByVehiculeIdAndDate(operation.getVehicule().getId(), date).isPresent();
        }
        if (!ligneActive && operation.getChauffeur() != null && operation.getChauffeur().getId() != null) {
            ligneActive = ligneCotisationRepository
                    .findActiveByChauffeurIdAndDate(operation.getChauffeur().getId(), date).isPresent();
        }
        if (!ligneActive) throw new VehiculeOuChauffeurSansLigneCotisationActiveException();
    }

    private void validerPenaliteAmendePending(OperationFinanciere operation) {
        Long vehiculeId  = operation.getVehicule()  != null ? operation.getVehicule().getId()  : null;
        Long chauffeurId = operation.getChauffeur() != null ? operation.getChauffeur().getId() : null;
        if (vehiculeId == null && chauffeurId == null) {
            throw new AucunePenaliteAmendePendingException();
        }
        if (!lignePenaliteRepository.hasAmendePendingByVehiculeOrChauffeur(
                vehiculeId != null ? vehiculeId : -1L,
                chauffeurId != null ? chauffeurId : -1L)) {
            throw new AucunePenaliteAmendePendingException();
        }
    }

    private String generateReference(TypeOperation type) {
        String prefix = type == TypeOperation.REVENU ? "REV" : "DEP";
        String year = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy"));
        String timestamp = String.valueOf(System.currentTimeMillis()).substring(7);
        return prefix + "-" + year + "-" + timestamp;
    }
}
