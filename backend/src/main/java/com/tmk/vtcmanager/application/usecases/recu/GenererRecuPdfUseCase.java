package com.tmk.vtcmanager.application.usecases.recu;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.domain.recu.LigneRecuPaiement;
import com.tmk.vtcmanager.application.domain.recu.RecuPaiement;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.versement.ImputationVersement;
import com.tmk.vtcmanager.application.domain.versement.NatureImputation;
import com.tmk.vtcmanager.application.exception.RecuImpossibleException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.document.RecuDocumentRenderer;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.ChauffeursAuProgrammeService;
import com.tmk.vtcmanager.application.services.LectureImputationService;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
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
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final ChauffeursAuProgrammeService chauffeursAuProgrammeService;
    private final CreanceRepository creanceRepository;

    public byte[] executer(List<Long> operationIds) {
        return recuDocumentRenderer.renderRecuPdf(construire(operationIds));
    }

    /**
     * Le même reçu, en données : ce que le client affiche avant l'envoi et
     * rédige en message. Mêmes refus que le PDF — ce qui ne se quittance pas
     * ne se propose pas non plus.
     */
    public RecuPaiement lire(List<Long> operationIds) {
        return construire(operationIds);
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
                resteDuJour(chauffeur == null ? null : chauffeur.getId(), imputations),
                chauffeur == null || chauffeur.getId() == null ? null : totalCreances(chauffeur.getId()),
                auVolant(chauffeur),
                LocalDateTime.now());
    }

    /**
     * Le total des créances du chauffeur, lu comme le module Créances le lit :
     * sur {@code v_creances_chauffeurs}, où le réglé se recompte sur les
     * encaissements non annulés (et non sur les colonnes dénormalisées
     * {@code montant_encaisse} / {@code statut}, qui décrochent), et où entrent
     * recettes, pénalités et contraventions échues. La cotisation n'y est pas :
     * c'est l'épargne du chauffeur, pas une dette — elle se dit dans le reste
     * du jour. Lu après l'encaissement, ce total tient déjà compte du reçu.
     */
    private BigDecimal totalCreances(Long chauffeurId) {
        return creanceRepository.getLignesCreance(chauffeurId).stream()
                .map(LigneCreance::getRestant)
                .filter(Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * Ce qui reste à payer sur la recette et la cotisation des journées que le
     * reçu couvre — et seulement celles-là : la créance du jour que le
     * versement n'a pas touchée (la cotisation quand seule la recette a été
     * versée) y compte aussi. Un reçu qui ne couvre aucune recette ni
     * cotisation — une pénalité seule — garde le reste de ses créances. Une
     * recette au réel n'a pas de dû d'avance : le reste est alors inconnu.
     */
    private BigDecimal resteDuJour(Long chauffeurId, List<ImputationVersement> imputations) {
        Set<LocalDate> journees = new LinkedHashSet<>();
        for (ImputationVersement imputation : imputations) {
            if ((imputation.nature() == NatureImputation.RECETTE
                    || imputation.nature() == NatureImputation.COTISATION)
                    && imputation.dateReference() != null) {
                journees.add(imputation.dateReference());
            }
        }
        if (chauffeurId == null || journees.isEmpty()) return resteDu(imputations);

        BigDecimal reste = BigDecimal.ZERO;
        for (LocalDate journee : journees) {
            for (LigneRecette ligne : ligneRecetteRepository.findByChauffeurIdAndDateRecette(chauffeurId, journee)) {
                if (ligne.getAnnuleLe() != null || ligne.getStatut() == StatutLigneRecette.ANNULEE) continue;
                if (ligne.getMontantAttendu() == null) return null;
                reste = reste.add(restant(ligne));
            }
            for (LigneCotisation ligne : ligneCotisationRepository.findByChauffeurIdAndDateCotisation(chauffeurId, journee)) {
                if (ligne.getAnnuleLe() != null || ligne.getMontantDu() == null
                        || ligne.getStatut() == StatutLigneCotisation.ANNULEE
                        || ligne.getStatut() == StatutLigneCotisation.RESTITUEE) continue;
                reste = reste.add(ligne.montantRestant());
            }
        }
        return reste;
    }

    /**
     * En service, le chauffeur roule aujourd'hui ou c'est son tour de repos —
     * le planning du jour tranche, comme sur la pastille de sa fiche. Tout
     * autre statut ne se salue ni d'une route ni d'un repos.
     */
    private Boolean auVolant(Chauffeur chauffeur) {
        if (chauffeur == null || chauffeur.getId() == null
                || chauffeur.getStatut() != ChauffeurStatus.EN_SERVICE) {
            return null;
        }
        return chauffeursAuProgrammeService.estAuProgramme(chauffeur.getId(), LocalDate.now());
    }

    private static BigDecimal restant(LigneRecette ligne) {
        if (ligne.getMontantAttendu() == null) return BigDecimal.ZERO;
        BigDecimal encaisse = ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
        return ligne.getMontantAttendu().subtract(encaisse).max(BigDecimal.ZERO);
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
