package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.ClotureCaisseDejaEffectueeException;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.exception.MotifEcartObligatoireException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@RequiredArgsConstructor
public class CloturerCaisseUseCase {

    private static final String CODE_MANQUANT = "ECART_CAISSE_MANQUANT";
    private static final String CODE_EXCEDENT = "ECART_CAISSE_EXCEDENT";

    private final CompteTresorerieRepository compteTresorerieRepository;
    private final ClotureCaisseRepository clotureCaisseRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;

    /**
     * Clôture le compte à la date du jour : compare le solde théorique au
     * comptage physique et, si écart, crée l'opération d'ajustement (motif
     * obligatoire) qui réaligne le solde sur le comptage.
     */
    @Transactional
    public ClotureCaisse executer(Long compteId, BigDecimal soldeCompte, String motifEcart) {
        LocalDate aujourdHui = LocalDate.now();
        if (clotureCaisseRepository.existsByCompteIdAndDateCloture(compteId, aujourdHui)) {
            throw new ClotureCaisseDejaEffectueeException(aujourdHui);
        }

        CompteAvecSolde compte = compteTresorerieRepository.findAvecSoldeById(compteId)
                .orElseThrow(() -> new CompteTresorerieNotFoundException(compteId));

        BigDecimal theorique = compte.getSolde();
        BigDecimal ecart = soldeCompte.subtract(theorique);

        Long operationId = null;
        if (ecart.compareTo(BigDecimal.ZERO) != 0) {
            if (motifEcart == null || motifEcart.isBlank()) {
                throw new MotifEcartObligatoireException();
            }
            operationId = creerOperationAjustement(compte, ecart, motifEcart).getId();
        }

        ClotureCaisse cloture = ClotureCaisse.builder()
                .compteId(compteId)
                .dateCloture(aujourdHui)
                .soldeTheorique(theorique)
                .soldeCompte(soldeCompte)
                .ecart(ecart)
                .motifEcart(motifEcart)
                .operationId(operationId)
                .build();
        return clotureCaisseRepository.save(cloture);
    }

    private OperationFinanciere creerOperationAjustement(CompteAvecSolde compte,
                                                         BigDecimal ecart, String motif) {
        boolean excedent = ecart.compareTo(BigDecimal.ZERO) > 0;
        CategorieOperation categorie = categorieOperationRepository
                .findByCode(excedent ? CODE_EXCEDENT : CODE_MANQUANT).orElse(null);

        TypeCompteTresorerie type = compte.getCompte().getType();
        OperationFinanciere operation = OperationFinanciere.builder()
                .typeOperation(excedent ? TypeOperation.REVENU : TypeOperation.DEPENSE)
                .categorie(categorie)
                .montant(ecart.abs())
                .modePaiement(type == TypeCompteTresorerie.MOBILE_MONEY
                        ? ModePaiement.MOBILE_MONEY : ModePaiement.ESPECES)
                .compteTresorerieId(compte.getCompte().getId())
                .dateOperation(LocalDate.now())
                .commentaire("Clôture de caisse — " + motif)
                .reference(genererReference())
                .statut(excedent ? StatutOperation.ENCAISSE : StatutOperation.PAYE)
                .build();
        return operationFinanciereRepository.save(operation);
    }

    private String genererReference() {
        String ts = String.valueOf(System.currentTimeMillis()).substring(7);
        return "CLO-" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy")) + "-" + ts;
    }
}
