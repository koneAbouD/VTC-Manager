package com.tmk.vtcmanager.application.usecases.recu;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.recu.LigneRecuPaiement;
import com.tmk.vtcmanager.application.domain.recu.RecuPaiement;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.versement.ImputationVersement;
import com.tmk.vtcmanager.application.exception.RecuImpossibleException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.document.RecuDocumentRenderer;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.LectureImputationService;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

/**
 * Produit le reçu PDF des écritures données : celles d'un versement, ou toutes
 * celles qu'un chauffeur a réglées d'un même geste de caisse.
 *
 * <p>Un reçu atteste un paiement : il ne peut donc couvrir qu'un argent qui
 * compte encore, reçu d'un seul payeur, pour ses créances. Tout le reste est
 * refusé, en nommant l'écriture en cause.
 */
@RequiredArgsConstructor
public class GenererRecuPdfUseCase {

    /** Au-delà, ce n'est plus un reçu mais un relevé de compte. */
    static final int MAX_ECRITURES = 60;

    /** Signature du reçu — la même que celle du message WhatsApp. */
    static final String ENTREPRISE = "TMK";

    private final OperationFinanciereRepository operationFinanciereRepository;
    private final LectureImputationService lectureImputationService;
    private final RecuDocumentRenderer recuDocumentRenderer;

    public byte[] executer(List<Long> operationIds) {
        return recuDocumentRenderer.renderRecuPdf(construire(operationIds));
    }

    private RecuPaiement construire(List<Long> operationIds) {
        List<Long> ids = operationIds == null ? List.of()
                : operationIds.stream().filter(Objects::nonNull).distinct().toList();
        if (ids.isEmpty()) {
            throw new RecuImpossibleException(
                    "Aucune écriture à quittancer : un reçu atteste au moins un versement.");
        }
        if (ids.size() > MAX_ECRITURES) {
            throw new RecuImpossibleException("Un reçu couvre au plus " + MAX_ECRITURES
                    + " écritures : au-delà, c'est un relevé de compte qu'il faut éditer.");
        }

        List<OperationFinanciere> ecritures = new ArrayList<>();
        List<ImputationVersement> imputations = new ArrayList<>();
        for (Long id : ids) {
            OperationFinanciere op = operationFinanciereRepository.findById(id)
                    .orElseThrow(() -> ResourceNotFoundException.of("Opération", id));
            if (op.estUneExtourne() || op.estExtournee() || op.getStatut() == StatutOperation.ANNULEE) {
                throw new RecuImpossibleException("L'écriture " + reference(op) + " a été annulée :"
                        + " un reçu ne peut pas attester un versement qui ne compte plus.");
            }
            ImputationVersement imputation = op.estUnEncaissement() ? lectureImputationService.lire(op) : null;
            if (imputation == null || imputation.nature() == null) {
                throw new RecuImpossibleException("L'écriture " + reference(op) + " ne règle ni une"
                        + " recette, ni une cotisation, ni une pénalité : elle ne se quittance pas au"
                        + " chauffeur.");
            }
            ecritures.add(op);
            imputations.add(imputation);
        }

        Set<Long> chauffeurs = new LinkedHashSet<>();
        ecritures.forEach(op -> chauffeurs.add(op.getChauffeur() == null ? null : op.getChauffeur().getId()));
        if (chauffeurs.size() > 1) {
            throw new RecuImpossibleException("Ces écritures ne sont pas au nom du même chauffeur :"
                    + " un reçu n'a qu'un destinataire. Éditez-en un par chauffeur.");
        }

        List<LigneRecuPaiement> lignes = new ArrayList<>();
        for (int i = 0; i < ecritures.size(); i++) {
            OperationFinanciere op = ecritures.get(i);
            ImputationVersement imputation = imputations.get(i);
            lignes.add(new LigneRecuPaiement(
                    imputation.libelle(),
                    imputation.nature(),
                    op.getDateReference() != null ? op.getDateReference() : op.getDateOperation(),
                    op.getDateOperation(),
                    op.getMontant(),
                    op.getReference(),
                    imputation.referencePaiement()));
        }
        // Par journée réglée, puis dans l'ordre du guichet : recette, cotisation, pénalité.
        lignes.sort(Comparator
                .comparing(LigneRecuPaiement::journee, Comparator.nullsLast(Comparator.naturalOrder()))
                .thenComparing(l -> l.nature().ordinal()));

        OperationFinanciere tete = ecritures.get(0);
        Chauffeur chauffeur = tete.getChauffeur();
        return new RecuPaiement(
                ENTREPRISE,
                nomComplet(chauffeur),
                chauffeur == null ? null : chauffeur.getTelephone(),
                ecritures.stream().map(OperationFinanciere::getVehicule).filter(Objects::nonNull)
                        .map(Vehicule::getImmatriculation).filter(Objects::nonNull).distinct().toList(),
                ecritures.stream().map(OperationFinanciere::getModePaiement).filter(Objects::nonNull)
                        .distinct().toList(),
                List.copyOf(lignes),
                resteDu(imputations),
                LocalDateTime.now());
    }

    /**
     * Ce qui reste dû sur les créances couvertes. Deux versements partiels de la
     * même recette partagent son reste : il ne compte qu'une fois. Une créance
     * qui ignore son reste — une recette au réel — rend le solde inconnu :
     * additionner les autres se lirait comme un solde complet.
     */
    private static BigDecimal resteDu(List<ImputationVersement> imputations) {
        Map<String, BigDecimal> parCreance = new LinkedHashMap<>();
        for (ImputationVersement imputation : imputations) {
            if (imputation.resteDu() == null) return null;
            parCreance.putIfAbsent(imputation.nature() + "#" + imputation.ligneId(), imputation.resteDu());
        }
        return parCreance.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static String reference(OperationFinanciere op) {
        return op.getReference() != null ? op.getReference() : "#" + op.getId();
    }

    private static String nomComplet(Chauffeur chauffeur) {
        if (chauffeur == null) return null;
        String prenom = chauffeur.getPrenom() != null ? chauffeur.getPrenom() : "";
        String nom = chauffeur.getNom() != null ? chauffeur.getNom() : "";
        String complet = (prenom + " " + nom).trim();
        return complet.isEmpty() ? null : complet;
    }
}
