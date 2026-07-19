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
public class ReverseContraventionUseCase {

    /** Catégorie HORS_RESULTAT : reverser à l'État n'est pas une charge. */
    private static final String CODE_CATEGORIE = "CONTRAVENTION_REVERSEMENT";

    private final ContraventionRepository contraventionRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final CompteTresorerieResolver compteTresorerieResolver;

    @Transactional
    public Contravention execute(Long id) {
        return execute(id, null);
    }

    /**
     * Reverse une contravention en traçant la référence de la quittance de l'État
     * (n° de liquidation/demande) dans le commentaire de l'opération de dépense.
     */
    @Transactional
    public Contravention execute(Long id, String referenceQuittance) {
        Contravention contravention = contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));
        contravention.reverser();
        Contravention saved = contraventionRepository.save(contravention);

        creerOperation(saved, referenceQuittance);
        return saved;
    }

    private void creerOperation(Contravention contravention, String referenceQuittance) {
        BigDecimal montant = contravention.getMontant();
        if (montant == null || montant.compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }
        CategorieOperation categorie = categorieOperationRepository.findByCode(CODE_CATEGORIE).orElse(null);

        OperationFinanciere operation = OperationFinanciere.builder()
                .typeOperation(TypeOperation.DEPENSE)
                .categorie(categorie)
                .chauffeur(contravention.getChauffeur())
                .vehicule(contravention.getVehicule())
                .montant(montant)
                .modePaiement(ModePaiement.ESPECES)
                .compteTresorerieId(compteTresorerieResolver.resoudre(null, ModePaiement.ESPECES))
                .dateOperation(LocalDate.now())
                .dateReference(contravention.getDateInfraction())
                .commentaire("Reversement contravention " + (contravention.getTypeInfraction() != null
                        ? contravention.getTypeInfraction() : "#" + contravention.getId()))
                .reference(genererReference())
                .statut(StatutOperation.PAYE)
                .build();

        operationFinanciereRepository.save(operation);
    }

    private String genererReference() {
        String ts = String.valueOf(System.currentTimeMillis()).substring(7);
        return "CTV-" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy")) + "-" + ts;
    }
}
