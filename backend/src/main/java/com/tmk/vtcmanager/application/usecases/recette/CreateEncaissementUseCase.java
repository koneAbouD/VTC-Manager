package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.ModeEncaissement;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.exception.EncaissementDepasseMontantAttenduException;
import com.tmk.vtcmanager.application.exception.LigneRecetteDejaSoldeeException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.exception.ModePaiementNonAutoriseException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@RequiredArgsConstructor
public class CreateEncaissementUseCase {

    private static final String CODE_CATEGORIE_ENCAISSEMENT = "ENCAISSEMENT_RECETTES";

    private final LigneRecetteRepository ligneRecetteRepository;
    private final EncaissementRepository encaissementRepository;
    private final ConfigurationRecetteRepository configurationRecetteRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;

    @Transactional
    public Encaissement executer(Long ligneRecetteId, Encaissement encaissement) {
        LigneRecette ligne = ligneRecetteRepository.findById(ligneRecetteId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneRecetteId));

        if (!ligne.estActive()) {
            throw new LigneRecetteDejaSoldeeException(ligneRecetteId);
        }

        validerModePaiement(ligne, encaissement.getModeEncaissement());
        validerMontant(ligne, encaissement.getMontant());

        encaissement.setLigneRecetteId(ligneRecetteId);

        OperationFinanciere operation = creerOperationFinanciere(ligne, encaissement);
        encaissement.setOperationFinanciereId(operation.getId());

        Encaissement saved = encaissementRepository.save(encaissement);

        // Recalcul du statut de la ligne via rechargement avec encaissements
        LigneRecette ligneComplete = ligneRecetteRepository.findById(ligneRecetteId).orElseThrow();
        ligneComplete.getEncaissements().add(saved);
        ligneComplete.recalculerStatutEtMontant();
        ligneRecetteRepository.updateStatutAndMontantEncaisse(
                ligneRecetteId,
                ligneComplete.getStatut(),
                ligneComplete.getMontantEncaisse());

        return saved;
    }

    private void validerModePaiement(LigneRecette ligne, ModePaiement mode) {
        ConfigurationRecette config = configurationRecetteRepository
                .findByVehiculeId(ligne.getVehiculeId())
                .orElse(null);
        if (config == null) return;

        ModeEncaissement modeConfig = config.getModeEncaissement();
        if (modeConfig == ModeEncaissement.LES_DEUX) return;
        if (modeConfig == ModeEncaissement.ESPECES && mode != ModePaiement.ESPECES) {
            throw new ModePaiementNonAutoriseException(mode.name(), modeConfig.name());
        }
        if (modeConfig == ModeEncaissement.MOBILE_MONEY && mode != ModePaiement.MOBILE_MONEY) {
            throw new ModePaiementNonAutoriseException(mode.name(), modeConfig.name());
        }
    }

    private void validerMontant(LigneRecette ligne, BigDecimal montantNouveau) {
        if (ligne.getMontantAttendu() == null) return; // MONTANT_REEL : pas de plafond
        BigDecimal restant = ligne.getMontantAttendu().subtract(ligne.getMontantEncaisse());
        if (montantNouveau.compareTo(restant) > 0) {
            throw new EncaissementDepasseMontantAttenduException(restant);
        }
    }

    private OperationFinanciere creerOperationFinanciere(LigneRecette ligne, Encaissement encaissement) {
        CategorieOperation categorie = categorieOperationRepository
                .findByCode(CODE_CATEGORIE_ENCAISSEMENT)
                .orElse(null);

        OperationFinanciere operation = OperationFinanciere.builder()
                .typeOperation(TypeOperation.REVENU)
                .categorie(categorie)
                .vehicule(vehiculeRef(ligne.getVehiculeId()))
                .chauffeur(chauffeurRef(ligne.getChauffeurId()))
                .montant(encaissement.getMontant())
                .modePaiement(encaissement.getModeEncaissement())
                .dateOperation(encaissement.getDateEncaissement())
                .dateReference(ligne.getDateRecette())
                .commentaire(encaissement.getCommentaire())
                .reference(genererReference())
                .statut(StatutOperation.ENCAISSE)
                .build();

        return operationFinanciereRepository.save(operation);
    }

    private com.tmk.vtcmanager.application.domain.vehicule.Vehicule vehiculeRef(Long id) {
        com.tmk.vtcmanager.application.domain.vehicule.Vehicule v = new com.tmk.vtcmanager.application.domain.vehicule.Vehicule();
        v.setId(id);
        return v;
    }

    private com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur chauffeurRef(Long id) {
        com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur c = new com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur();
        c.setId(id);
        return c;
    }

    private String genererReference() {
        String timestamp = String.valueOf(System.currentTimeMillis()).substring(7);
        return "ENC-" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy")) + "-" + timestamp;
    }
}
