package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.arrete.StatutArrete;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CaisseCreditriceGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.stream.Stream;

/**
 * Exécute un arrêté de compte : fige le décompte, compense les créances par
 * antériorité via des encaissements <b>cash-neutres</b> (opération sans compte de
 * trésorerie — le cash est déjà entré via la cotisation), décaisse le net positif
 * (« prime », HORS_RESULTAT) et sort du fonds les cotisations rendues.
 *
 * <p>Une cotisation n'est marquée RESTITUEE que si elle était intégralement
 * encaissée. Partiellement payée, elle voit seulement sa part rendue consignée
 * et reste une créance ouverte pour le solde : la restituer en entier effacerait
 * de la balance âgée une dette que rien n'a éteinte.</p>
 *
 * <p>Le versement se résout toujours par bénéficiaire chauffeur : un arrêté par
 * véhicule multi-chauffeur produit plusieurs règlements.</p>
 */
@RequiredArgsConstructor
public class ArreterCompteUseCase {

    private static final String CAT_RESTITUTION = "RESTITUTION_COTISATIONS";
    private static final String CAT_RECETTE = "ENCAISSEMENT_RECETTES";
    private static final String CAT_PENALITE = "ENCAISSEMENT_PENALITES";
    private static final String CAT_CONTRAVENTION = "CONTRAVENTION_REMBOURSEMENT";
    private static final DateTimeFormatter ANNEE = DateTimeFormatter.ofPattern("yyyy");

    private final CalculerCompteCourantUseCase calculerCompteCourantUseCase;
    private final ArreteCompteRepository arreteCompteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final EncaissementRepository encaissementRepository;
    private final LignePenaliteRepository lignePenaliteRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final ContraventionRepository contraventionRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;
    private final CompteTresorerieResolver compteTresorerieResolver;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final SequenceReferenceService sequenceReferenceService;
    private final CaisseClotureeGuard caisseClotureeGuard;
    private final CaisseCreditriceGuard caisseCreditriceGuard;

    /**
     * Arrêté total : toutes les cotisations et créances de la période.
     *
     * <p>Annotée elle aussi : sans cela, l'appel qu'elle délègue passe par
     * {@code this} et non par le proxy, et la surcharge ci-dessous s'exécuterait
     * hors transaction — une compensation échouée laisserait derrière elle des
     * cotisations déjà marquées restituées.
     */
    @Transactional
    public ArreteCompte executer(PerimetreArrete perimetre, Long perimetreId,
                                 LocalDate periodeDebut, LocalDate periodeFin,
                                 LocalDate dateArrete, ModePaiement modePaiement,
                                 Long compteTresorerieId) {
        return executer(perimetre, perimetreId, periodeDebut, periodeFin,
                dateArrete, modePaiement, compteTresorerieId, SelectionArrete.tout());
    }

    /** Arrêté restreint à la sélection de lignes (restitution partielle). */
    @Transactional
    public ArreteCompte executer(PerimetreArrete perimetre, Long perimetreId,
                                 LocalDate periodeDebut, LocalDate periodeFin,
                                 LocalDate dateArrete, ModePaiement modePaiement,
                                 Long compteTresorerieId, SelectionArrete selection) {
        if (periodeFin.isBefore(periodeDebut)) {
            throw new IllegalArgumentException("La fin de période ne peut précéder son début.");
        }
        LocalDate effetArrete = dateArrete != null ? dateArrete : LocalDate.now();
        periodeClotureeGuard.verifier(effetArrete);

        // Deux arrêtés menés de front — l'un par chauffeur, l'autre par
        // véhicule — voient la même créance ouverte et la compenseraient tous
        // les deux. Rien ne marque une créance « en cours d'arrêté » : la seule
        // protection est de les sérialiser. Ils sont rares, le coût est nul.
        arreteCompteRepository.verrouillerExecution();

        List<DecompteBeneficiaire> decomptes =
                calculerCompteCourantUseCase.calculer(perimetre, perimetreId, periodeDebut, periodeFin, selection)
                        .stream()
                        .filter(DecompteBeneficiaire::aMatiereAArreter)
                        .toList();
        if (decomptes.isEmpty()) {
            throw new IllegalArgumentException(
                    "Aucune cotisation à restituer ni créance à compenser sur cette période.");
        }

        // Le versement, s'il y en a un, sort d'un seul compte : celui du mode de
        // paiement. On le résout et on l'éprouve ici, avant la première
        // écriture, sur le TOTAL à verser et non chauffeur par chauffeur — un
        // arrêté par véhicule en paie plusieurs, et les contrôler séparément
        // laisserait passer un cumul que la caisse ne peut pas honorer. Le
        // premier versement serait alors déjà écrit quand le troisième
        // échouerait, et le message parlerait d'un solde que les précédents
        // avaient déjà entamé.
        ModePaiement mode = modePaiement != null ? modePaiement : ModePaiement.ESPECES;
        BigDecimal totalAVerser = decomptes.stream()
                .map(DecompteBeneficiaire::getNet)
                .filter(net -> net.signum() > 0)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        Long compteVersement = null;
        if (totalAVerser.signum() > 0) {
            compteVersement = resoudreCompteVersement(compteTresorerieId, mode);
            caisseClotureeGuard.verifier(compteVersement, effetArrete);
            caisseCreditriceGuard.verifier(compteVersement, totalAVerser, effetArrete);
        }

        String reference = sequenceReferenceService.suivante(SequenceReferenceService.Journal.ARRETE);

        ArreteCompte entete = arreteCompteRepository.enregistrerEntete(ArreteCompte.builder()
                .perimetre(perimetre)
                .perimetreId(perimetreId)
                .periodeDebut(debutEffectif(decomptes, periodeDebut))
                .periodeFin(finEffective(decomptes, periodeFin))
                .dateArrete(effetArrete)
                .reference(reference)
                .statut(StatutArrete.VALIDE)
                .build());
        Long arreteId = entete.getId();

        List<LigneArrete> lignes = new ArrayList<>();
        List<ReglementArrete> reglements = new ArrayList<>();

        for (DecompteBeneficiaire d : decomptes) {
            // Snapshot du fonds (cotisations, au crédit) + passage en RESTITUEE.
            for (LigneCotisation cot : d.getCotisations()) {
                // La part rendue est le fonds encore détenu, pas l'encaissement
                // brut : une ligne déjà entamée par un arrêté précédent ne rend
                // que ce qu'il en reste.
                BigDecimal partRendue = cot.fondRestituable();
                lignes.add(LigneArrete.builder()
                        .arreteId(arreteId)
                        .document(TypeDocumentCreance.COTISATION)
                        .documentId(cot.getId())
                        .chauffeurId(cot.getChauffeurId())
                        .vehiculeId(cot.getVehiculeId())
                        .dateDocument(cot.getDateCotisation())
                        .montant(partRendue)
                        .sens(SensArrete.CREDIT)
                        .build());
                ligneCotisationRepository.marquerRestituee(cot.getId(), arreteId, partRendue);
            }

            // Compensation des créances (au débit), par antériorité, cash-neutre.
            for (DecompteBeneficiaire.Allocation alloc : d.getAllocations()) {
                LigneCreance creance = alloc.getCreance();
                Long operationId = compenser(creance, alloc.getMontant(), effetArrete, reference);
                lignes.add(LigneArrete.builder()
                        .arreteId(arreteId)
                        .document(creance.getDocument())
                        .documentId(creance.getDocumentId())
                        .chauffeurId(d.getChauffeurId())
                        .vehiculeId(creance.getVehiculeId())
                        .dateDocument(creance.getDateReference())
                        .montant(alloc.getMontant())
                        .sens(SensArrete.DEBIT)
                        .operationId(operationId)
                        .build());
            }

            // Décaissement du net positif (« prime »).
            Long operationDecaissementId = null;
            if (d.getNet().signum() > 0) {
                operationDecaissementId = decaisserNet(d, perimetre, perimetreId, effetArrete,
                        mode, compteVersement, reference).getId();
            }

            reglements.add(ReglementArrete.builder()
                    .arreteId(arreteId)
                    .chauffeurId(d.getChauffeurId())
                    .chauffeurNom(d.getChauffeurNom())
                    .totalCotisations(d.getFond())
                    .totalCreancesCompensees(d.getTotalCompense())
                    .montantNet(d.getNet())
                    .reliquatReporte(d.getReliquat())
                    .modePaiement(d.getNet().signum() > 0 ? mode : null)
                    .compteTresorerieId(operationDecaissementId != null ? compteVersement : null)
                    .operationDecaissementId(operationDecaissementId)
                    .build());
        }

        arreteCompteRepository.enregistrerLignes(lignes);
        arreteCompteRepository.enregistrerReglements(reglements);

        return arreteCompteRepository.findById(arreteId).orElse(entete);
    }

    /** Éteint une créance sans mouvementer la trésorerie (compte null) ; renvoie l'id de l'opération de compensation. */
    private Long compenser(LigneCreance creance, BigDecimal montant, LocalDate date, String refArrete) {
        switch (creance.getDocument()) {
            case RECETTE -> {
                OperationFinanciere op = creerOperationCompensation(
                        CAT_RECETTE, creance, montant, date, refArrete, null);
                encaissementRepository.save(Encaissement.builder()
                        .ligneRecetteId(creance.getDocumentId())
                        .operationFinanciereId(op.getId())
                        .montant(montant)
                        .modeEncaissement(ModePaiement.ESPECES)
                        .dateEncaissement(date)
                        .reference(op.getReference())
                        .commentaire("Compensation cotisation " + refArrete)
                        .build());
                ligneRecetteRepository.recalculerDepuisEncaissements(creance.getDocumentId());
                return op.getId();
            }
            case PENALITE -> {
                OperationFinanciere op = creerOperationCompensation(
                        CAT_PENALITE, creance, montant, date, refArrete, null);
                encaissementPenaliteRepository.save(EncaissementPenalite.builder()
                        .lignePenaliteId(creance.getDocumentId())
                        .operationFinanciereId(op.getId())
                        .montant(montant)
                        .modeEncaissement(ModePaiement.ESPECES)
                        .dateEncaissement(date)
                        .reference(op.getReference())
                        .commentaire("Compensation cotisation " + refArrete)
                        .build());
                lignePenaliteRepository.recalculerDepuisEncaissements(creance.getDocumentId());
                return op.getId();
            }
            case CONTRAVENTION -> {
                var contravention = contraventionRepository.findById(creance.getDocumentId())
                        .orElseThrow(() -> new IllegalStateException(
                                "Contravention introuvable : " + creance.getDocumentId()));
                contravention.enregistrerPaiement(montant);
                contraventionRepository.save(contravention);
                return creerOperationCompensation(CAT_CONTRAVENTION, creance, montant, date, refArrete,
                        contravention.getId()).getId();
            }
            case COTISATION -> { /* jamais compensée : le fonds ne se compense pas lui-même */ }
        }
        return null;
    }

    /**
     * @param contraventionId contravention éteinte par cette compensation, ou
     *                        null pour les autres créances : c'est ce lien qui
     *                        permet de la rendre à son état antérieur si
     *                        l'écriture est un jour extournée.
     */
    private OperationFinanciere creerOperationCompensation(String codeCategorie, LigneCreance creance,
                                                          BigDecimal montant, LocalDate date, String refArrete,
                                                          Long contraventionId) {
        CategorieOperation categorie = categorieOperationRepository.findByCode(codeCategorie).orElse(null);
        OperationFinanciere op = OperationFinanciere.builder()
                .contraventionId(contraventionId)
                .typeOperation(TypeOperation.REVENU)
                .categorie(categorie)
                .chauffeur(chauffeurRef(creance.getChauffeurId()))
                .vehicule(vehiculeRef(creance.getVehiculeId()))
                .montant(montant)
                .modePaiement(ModePaiement.ESPECES)
                .compteTresorerieId(null) // cash-neutre : le cash est déjà entré via la cotisation
                .dateOperation(date)
                .dateReference(creance.getDateReference())
                .commentaire("Compensation cotisation " + refArrete)
                .reference(sequenceReferenceService.suivante(SequenceReferenceService.Journal.COMPENSATION))
                .statut(StatutOperation.ENCAISSE)
                .build();
        return operationFinanciereRepository.save(op);
    }

    /**
     * Le compte que le mode de paiement désigne : la caisse pour des espèces, le
     * portefeuille pour du mobile money. L'appelant peut en imposer un — c'est
     * ce que fait un client qui sait déjà lequel débiter —, sinon c'est le
     * compte marqué par défaut pour ce type qui répond.
     *
     * <p>Sans compte, l'écriture ne sortirait d'aucune caisse : le chauffeur
     * repartirait avec l'argent sans que la trésorerie ne bouge, et les deux
     * verrous — qui s'effacent devant un compte nul — laisseraient passer le
     * versement en silence. Le résolveur tolère cette absence pour les écritures
     * historiques ; un décaissement, non.
     */
    private Long resoudreCompteVersement(Long compteImpose, ModePaiement mode) {
        Long compteId = compteTresorerieResolver.resoudre(compteImpose, mode);
        if (compteId == null) {
            throw new IllegalStateException(
                    "Aucun compte de trésorerie pour un versement en "
                    + (mode == ModePaiement.MOBILE_MONEY ? "mobile money" : "espèces")
                    + " : marquez-en un par défaut pour ce mode de paiement.");
        }
        return compteId;
    }

    /** Verse le net d'un bénéficiaire. Le compte est déjà résolu et éprouvé par l'appelant. */
    private OperationFinanciere decaisserNet(DecompteBeneficiaire d, PerimetreArrete perimetre, Long perimetreId,
                                             LocalDate date, ModePaiement mode, Long compteId,
                                             String refArrete) {
        CategorieOperation categorie = categorieOperationRepository.findByCode(CAT_RESTITUTION).orElse(null);
        OperationFinanciere op = OperationFinanciere.builder()
                .typeOperation(TypeOperation.DEPENSE)
                .categorie(categorie)
                .chauffeur(chauffeurRef(d.getChauffeurId()))
                .vehicule(perimetre == PerimetreArrete.VEHICULE ? vehiculeRef(perimetreId) : null)
                .montant(d.getNet())
                .modePaiement(mode)
                .compteTresorerieId(compteId)
                .dateOperation(date)
                .dateReference(date)
                .commentaire("Restitution cotisations " + refArrete + " - " + d.getChauffeurNom())
                .reference(sequenceReferenceService.suivante(SequenceReferenceService.Journal.RESTITUTION))
                .statut(StatutOperation.PAYE)
                .build();
        return operationFinanciereRepository.save(op);
    }

    /**
     * Période réellement couverte, resserrée sur les cotisations restituées.
     *
     * <p>L'utilisateur qui vide tout un compte courant demande « depuis
     * toujours » : garder ses bornes telles quelles ferait figurer dans
     * l'historique et sur le décompte PDF une période qui commence des années
     * avant la première cotisation. On borne donc à ce qui a été arrêté, en
     * gardant les bornes demandées quand rien ne permet de resserrer.
     */
    private LocalDate debutEffectif(List<DecompteBeneficiaire> decomptes, LocalDate demande) {
        return datesCotisations(decomptes).min(LocalDate::compareTo).orElse(demande);
    }

    private LocalDate finEffective(List<DecompteBeneficiaire> decomptes, LocalDate demandee) {
        return datesCotisations(decomptes).max(LocalDate::compareTo).orElse(demandee);
    }

    private Stream<LocalDate> datesCotisations(List<DecompteBeneficiaire> decomptes) {
        return decomptes.stream()
                .flatMap(d -> d.getCotisations().stream())
                .map(LigneCotisation::getDateCotisation)
                .filter(Objects::nonNull);
    }

    private Vehicule vehiculeRef(Long id) {
        if (id == null) return null;
        Vehicule v = new Vehicule();
        v.setId(id);
        return v;
    }

    private Chauffeur chauffeurRef(Long id) {
        if (id == null) return null;
        Chauffeur c = new Chauffeur();
        c.setId(id);
        return c;
    }

    /** Références uniques (VARCHAR(30)) : préfixe + année + horodatage nanos (base 36, monotone). */
}
