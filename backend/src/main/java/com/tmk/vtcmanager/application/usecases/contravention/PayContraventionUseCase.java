package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@RequiredArgsConstructor
public class PayContraventionUseCase {

    /**
     * Catégorie HORS_RESULTAT (compte de tiers) : le remboursement d'une
     * amende par le chauffeur mouvemente la trésorerie mais n'est pas un
     * produit d'exploitation.
     */
    private static final String CODE_CATEGORIE = "CONTRAVENTION_REMBOURSEMENT";

    private final ContraventionRepository contraventionRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final CompteTresorerieResolver compteTresorerieResolver;

    @Transactional
    public Contravention execute(Long id, BigDecimal montant, ModePaiement modePaiement) {
        Contravention contravention = contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));
        contravention.enregistrerPaiement(montant);
        Contravention saved = contraventionRepository.save(contravention);

        creerOperation(saved, montant, modePaiement != null ? modePaiement : ModePaiement.ESPECES);
        return saved;
    }

    private void creerOperation(Contravention contravention, BigDecimal montant, ModePaiement modePaiement) {
        CategorieOperation categorie = categorieOperationRepository.findByCode(CODE_CATEGORIE).orElse(null);

        OperationFinanciere operation = OperationFinanciere.builder()
                .typeOperation(TypeOperation.REVENU)
                .categorie(categorie)
                .chauffeur(contravention.getChauffeur())
                .vehicule(contravention.getVehicule())
                .montant(montant)
                .modePaiement(modePaiement)
                .compteTresorerieId(compteTresorerieResolver.resoudre(null, modePaiement))
                .dateOperation(LocalDate.now())
                .dateReference(contravention.getDateInfraction())
                .commentaire("Remboursement contravention " + (contravention.getTypeInfraction() != null
                        ? contravention.getTypeInfraction() : "#" + contravention.getId()))
                .reference(genererReference())
                .statut(StatutOperation.ENCAISSE)
                .build();

        operationFinanciereRepository.save(operation);
    }

    private String genererReference() {
        String ts = String.valueOf(System.currentTimeMillis()).substring(7);
        return "CTR-" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy")) + "-" + ts;
    }
}
