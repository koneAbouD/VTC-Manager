package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * Calcule (sans rien écrire) le décompte d'un arrêté de compte : par bénéficiaire
 * chauffeur, le fonds de cotisation de la période face aux créances ouvertes,
 * l'allocation de compensation par antériorité, le net et le reliquat.
 *
 * <p>Fonds = Σ de la part <b>encore détenue</b> des cotisations actives
 * (montant_encaisse − montant_restitue) : une ligne déjà rendue en partie par un
 * arrêté précédent n'y revient pas. Les cotisations impayées ne sont pas dans le
 * fonds et ne sont pas comptées comme créance ici — mathématiquement équivalent
 * à « cotisations dues − créances incl. cotisations impayées » —, mais elles
 * restent dues dans la balance âgée tant qu'elles ne sont pas soldées.</p>
 *
 * <p><b>Mutualisation par véhicule.</b> Chaque chauffeur éteint d'abord ses
 * propres créances. Sur un arrêté <b>par véhicule</b>, le fonds qui lui reste
 * ensuite éteint les créances que les autres chauffeurs du véhicule n'ont pas
 * pu couvrir : le véhicule est alors une caisse commune, et l'argent déposé par
 * l'un peut solder la dette de l'autre — celui qui a financé voit d'autant
 * baisser le net qui lui est versé. Sur un arrêté <b>par chauffeur</b>, il n'y a
 * qu'un bénéficiaire : rien ne se croise.</p>
 */
@RequiredArgsConstructor
public class CalculerCompteCourantUseCase {

    private static final Set<StatutLigneCotisation> STATUTS_FONDS = Set.of(
            StatutLigneCotisation.EN_ATTENTE,
            StatutLigneCotisation.PARTIELLEMENT_ENCAISSE,
            StatutLigneCotisation.ENCAISSE);

    /**
     * L'ordre dans lequel un fonds éteint les créances : la plus ancienne
     * d'abord. L'identifiant départage deux documents du même jour, pour que le
     * décompte affiché et le décompte enregistré parlent des mêmes lignes.
     */
    private static final Comparator<CreanceOuverte> PAR_ANTERIORITE =
            Comparator.<CreanceOuverte, LocalDate>comparing(c -> c.ligne.getDateReference(),
                            Comparator.nullsLast(Comparator.naturalOrder()))
                    .thenComparing(c -> c.ligne.getDocumentId());

    private final LigneCotisationRepository ligneCotisationRepository;
    private final CreanceRepository creanceRepository;
    private final ChauffeurRepository chauffeurRepository;

    /** Décomptes par bénéficiaire (arrêté total : toutes les lignes). */
    public List<DecompteBeneficiaire> calculer(PerimetreArrete perimetre, Long perimetreId,
                                               LocalDate debut, LocalDate fin) {
        return calculer(perimetre, perimetreId, debut, fin, SelectionArrete.tout());
    }

    /**
     * Décomptes par bénéficiaire (seuls ceux avec matière à arrêter), restreints à
     * la sélection : seules les cotisations retenues forment le fonds et seules les
     * créances retenues sont compensables (arrêté partiel).
     *
     * <p><b>La période ne borne que le fonds.</b> Les créances ouvertes sont prises
     * toutes périodes confondues : un dépôt doit pouvoir éteindre une dette plus
     * ancienne que lui, et la compensation se fait par antériorité. C'est aux
     * écrans de dire lesquelles sortent de la période demandée.</p>
     */
    public List<DecompteBeneficiaire> calculer(PerimetreArrete perimetre, Long perimetreId,
                                               LocalDate debut, LocalDate fin,
                                               SelectionArrete selection) {
        Long vehiculeId = perimetre == PerimetreArrete.VEHICULE ? perimetreId : null;

        List<Brouillon> brouillons = new ArrayList<>();
        for (Long chauffeurId : resoudreBeneficiaires(perimetre, perimetreId, debut, fin)) {
            List<LigneCotisation> cotisations = cotisationsFonds(chauffeurId, vehiculeId, debut, fin).stream()
                    .filter(selection::cotisationIncluse)
                    .toList();
            // Toutes les créances ouvertes, y compris celles que la sélection
            // écarte : le reliquat se mesure sur ce que le chauffeur doit
            // vraiment. N'en garder que les cochées ferait déclarer à l'arrêté —
            // et à son PDF — une dette résiduelle inférieure à la réalité, alors
            // qu'il suffit d'en décocher une pour qu'elle cesse d'exister sur le
            // papier.
            List<CreanceOuverte> creances = creancesOuvertes(chauffeurId, vehiculeId).stream()
                    .map(c -> new CreanceOuverte(c, selection.creanceIncluse(c)))
                    .toList();
            brouillons.add(new Brouillon(chauffeurId, cotisations, creances));
        }

        // 1. Chacun éteint d'abord ses propres créances : son dépôt lui revient
        //    en priorité, et un chauffeur à jour ne finance rien tant qu'il doit.
        brouillons.forEach(b -> imputer(b, b.creances));

        // 2. Sur un arrêté par véhicule, ce qui reste disponible passe aux
        //    créances encore ouvertes des autres chauffeurs du véhicule, dans
        //    l'ordre d'antériorité — la plus vieille dette du véhicule d'abord,
        //    peu importe qui la porte.
        if (perimetre == PerimetreArrete.VEHICULE) {
            List<CreanceOuverte> duVehicule = brouillons.stream()
                    .flatMap(b -> b.creances.stream())
                    .sorted(PAR_ANTERIORITE)
                    .toList();
            brouillons.forEach(b -> imputer(b, duVehicule));
        }

        return brouillons.stream()
                .map(this::figer)
                .filter(DecompteBeneficiaire::estNonVide)
                .toList();
    }

    /**
     * Aperçu non persisté : un ArreteCompte transient prêt à afficher.
     *
     * <p>Toutes les créances ouvertes y figurent, pas seulement celles que le
     * fonds atteint : chaque ligne porte ce qu'elle éteint ({@code montant}) et
     * ce qu'elle doit ({@code restant}). Ne montrer que les créances couvertes
     * laissait l'utilisateur valider sans voir le reste dû, et lui interdisait
     * d'arbitrer entre une vieille créance et une récente.
     */
    public ArreteCompte construireApercu(PerimetreArrete perimetre, Long perimetreId,
                                         LocalDate debut, LocalDate fin) {
        List<DecompteBeneficiaire> decomptes = calculer(perimetre, perimetreId, debut, fin);
        // Ce qu'une créance reçoit, tous financeurs confondus : sur un arrêté par
        // véhicule elle peut être couverte par le fonds de plusieurs chauffeurs,
        // et n'afficher que la part de son propriétaire la ferait passer pour
        // moins couverte qu'elle ne l'est.
        Map<SelectionArrete.CreanceKey, BigDecimal> impute = new LinkedHashMap<>();
        for (DecompteBeneficiaire.Allocation a : compensationsCumulees(decomptes)) {
            impute.put(cle(a.getCreance()), a.getMontant());
        }

        List<LigneArrete> lignes = new ArrayList<>();
        List<ReglementArrete> reglements = new ArrayList<>();
        for (DecompteBeneficiaire d : decomptes) {
            for (LigneCotisation cot : d.getCotisations()) {
                lignes.add(LigneArrete.builder()
                        .document(TypeDocumentCreance.COTISATION)
                        .documentId(cot.getId())
                        .chauffeurId(cot.getChauffeurId())
                        .vehiculeId(cot.getVehiculeId())
                        .dateDocument(cot.getDateCotisation())
                        .montant(cot.fondRestituable())
                        .sens(SensArrete.CREDIT)
                        .build());
            }
            for (LigneCreance c : d.getCreances()) {
                lignes.add(LigneArrete.builder()
                        .document(c.getDocument())
                        .documentId(c.getDocumentId())
                        .chauffeurId(d.getChauffeurId())
                        .vehiculeId(c.getVehiculeId())
                        .dateDocument(c.getDateReference())
                        .montant(impute.getOrDefault(cle(c), BigDecimal.ZERO))
                        .restant(c.getRestant())
                        .montantDu(c.getMontantDu())
                        .sens(SensArrete.DEBIT)
                        .build());
            }
            reglements.add(ReglementArrete.builder()
                    .chauffeurId(d.getChauffeurId())
                    .chauffeurNom(d.getChauffeurNom())
                    .totalCotisations(d.getFond())
                    .totalCreancesCompensees(d.getTotalCompense())
                    .montantNet(d.getNet())
                    .reliquatReporte(d.getReliquat())
                    .build());
        }

        return ArreteCompte.builder()
                .perimetre(perimetre)
                .perimetreId(perimetreId)
                .periodeDebut(debut)
                .periodeFin(fin)
                .lignes(lignes)
                .reglements(reglements)
                .build();
    }

    /**
     * Les créances que l'arrêté éteint, une entrée par document, avec le total
     * imputé dessus.
     *
     * <p>Sur un arrêté par véhicule, le fonds de plusieurs chauffeurs peut
     * couvrir la même créance. Elle ne doit pourtant donner qu'une écriture de
     * compensation et qu'une ligne d'arrêté : deux encaissements pour un même
     * document se liraient comme deux versements du chauffeur, et l'annulation
     * aurait deux fois la même créance à rouvrir.</p>
     */
    public static List<DecompteBeneficiaire.Allocation> compensationsCumulees(
            List<DecompteBeneficiaire> decomptes) {
        Map<SelectionArrete.CreanceKey, DecompteBeneficiaire.Allocation> parDocument =
                new LinkedHashMap<>();
        for (DecompteBeneficiaire d : decomptes) {
            for (DecompteBeneficiaire.Allocation a : d.getAllocations()) {
                parDocument.merge(cle(a.getCreance()), a,
                        (deja, ajout) -> new DecompteBeneficiaire.Allocation(deja.getCreance(),
                                deja.getMontant().add(ajout.getMontant())));
            }
        }
        return List.copyOf(parDocument.values());
    }

    // ── Interne ──────────────────────────────────────────────────────────────

    /**
     * Impute le fonds encore disponible d'un chauffeur sur des créances, de la
     * plus ancienne à la plus récente. Rejouable : une créance déjà éteinte ou
     * décochée est passée, et un fonds épuisé arrête la boucle — c'est ce qui
     * permet de rappeler la méthode pour la mutualisation sans rien compter deux
     * fois.
     */
    private void imputer(Brouillon b, List<CreanceOuverte> creances) {
        for (CreanceOuverte c : creances) {
            if (b.disponible.signum() <= 0) return;
            if (!c.retenue || c.reste.signum() <= 0) continue;
            BigDecimal part = b.disponible.min(c.reste);
            b.allocations.add(new DecompteBeneficiaire.Allocation(c.ligne, part));
            b.disponible = b.disponible.subtract(part);
            c.reste = c.reste.subtract(part);
        }
    }

    /** Fige un brouillon en décompte : les totaux se lisent sur l'état final des créances. */
    private DecompteBeneficiaire figer(Brouillon b) {
        BigDecimal totalCompense = b.allocations.stream()
                .map(DecompteBeneficiaire.Allocation::getMontant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        // Ce qui reste dû SUR SES créances, quel que soit le fonds qui les a
        // entamées : sur un arrêté par véhicule, une dette éteinte par le
        // chauffeur d'à côté n'est plus un reliquat pour son porteur.
        BigDecimal reliquat = b.creances.stream()
                .map(c -> c.reste)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        // Ce que l'arrêté éteint sur SES créances, quel que soit le fonds qui
        // paie : c'est ce qui garde à l'écran le chauffeur sans dépôt dont un
        // collègue solde la dette.
        BigDecimal compenseSurSesCreances = b.creances.stream()
                .map(c -> c.ligne.getRestant().subtract(c.reste))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        List<LigneCreance> retenues = b.creances.stream()
                .filter(c -> c.retenue)
                .map(c -> c.ligne)
                .toList();
        return new DecompteBeneficiaire(b.chauffeurId,
                nomChauffeur(b.chauffeurId, b.cotisations, retenues),
                b.cotisations, b.fond, retenues, b.allocations,
                totalCompense, b.fond.subtract(totalCompense), reliquat,
                compenseSurSesCreances);
    }

    private static SelectionArrete.CreanceKey cle(LigneCreance creance) {
        return new SelectionArrete.CreanceKey(creance.getDocument(), creance.getDocumentId());
    }

    private Set<Long> resoudreBeneficiaires(PerimetreArrete perimetre, Long perimetreId,
                                            LocalDate debut, LocalDate fin) {
        if (perimetre == PerimetreArrete.CHAUFFEUR) {
            return new LinkedHashSet<>(List.of(perimetreId));
        }
        // VEHICULE : tous les chauffeurs ayant un fonds sur la période OU une créance ouverte sur ce véhicule.
        Set<Long> beneficiaires = new LinkedHashSet<>();
        cotisationsFonds(null, perimetreId, debut, fin)
                .forEach(l -> beneficiaires.add(l.getChauffeurId()));
        creanceRepository.getLignesCreanceParVehicule(perimetreId).stream()
                .filter(c -> c.getDocument() != TypeDocumentCreance.COTISATION)
                .filter(c -> c.getChauffeurId() != null)
                .forEach(c -> beneficiaires.add(c.getChauffeurId()));
        return beneficiaires;
    }

    private List<LigneCotisation> cotisationsFonds(Long chauffeurId, Long vehiculeId,
                                                   LocalDate debut, LocalDate fin) {
        LigneCotisationFiltres filtres = LigneCotisationFiltres.builder()
                .chauffeurId(chauffeurId)
                .vehiculeId(vehiculeId)
                .dateDebut(debut)
                .dateFin(fin)
                .build();
        return ligneCotisationRepository.findByCriteres(filtres).stream()
                .filter(l -> STATUTS_FONDS.contains(l.getStatut()))
                .filter(l -> l.fondRestituable().signum() > 0)
                .toList();
    }

    private List<LigneCreance> creancesOuvertes(Long chauffeurId, Long vehiculeId) {
        return creanceRepository.getLignesCreance(chauffeurId).stream()
                .filter(c -> c.getDocument() != TypeDocumentCreance.COTISATION)
                .filter(c -> vehiculeId == null || vehiculeId.equals(c.getVehiculeId()))
                .filter(c -> c.getRestant() != null && c.getRestant().signum() > 0)
                .toList();
    }

    private String nomChauffeur(Long chauffeurId, List<LigneCotisation> cotisations, List<LigneCreance> creances) {
        Optional<Chauffeur> ch = chauffeurRepository.findById(chauffeurId);
        if (ch.isPresent()) {
            String prenom = ch.get().getPrenom() != null ? ch.get().getPrenom() : "";
            String nom = ch.get().getNom() != null ? ch.get().getNom() : "";
            String complet = (prenom + " " + nom).trim();
            if (!complet.isEmpty()) return complet;
        }
        return cotisations.stream().map(LigneCotisation::getChauffeurNom).filter(n -> n != null && !n.isBlank())
                .findFirst()
                .or(() -> creances.stream().map(LigneCreance::getChauffeurNom).filter(n -> n != null && !n.isBlank()).findFirst())
                .orElse("Chauffeur #" + chauffeurId);
    }

    /** Créance en cours d'imputation : ce qu'il en reste à mesure que les fonds l'éteignent. */
    private static final class CreanceOuverte {
        private final LigneCreance ligne;
        /** Retenue par la sélection : une créance décochée n'est pas compensable. */
        private final boolean retenue;
        private BigDecimal reste;

        private CreanceOuverte(LigneCreance ligne, boolean retenue) {
            this.ligne = ligne;
            this.retenue = retenue;
            this.reste = ligne.getRestant();
        }
    }

    /** Matière d'un bénéficiaire pendant le calcul, avant d'être figée en décompte. */
    private static final class Brouillon {
        private final Long chauffeurId;
        private final List<LigneCotisation> cotisations;
        private final List<CreanceOuverte> creances;
        private final List<DecompteBeneficiaire.Allocation> allocations = new ArrayList<>();
        private final BigDecimal fond;
        private BigDecimal disponible;

        private Brouillon(Long chauffeurId, List<LigneCotisation> cotisations,
                          List<CreanceOuverte> creances) {
            this.chauffeurId = chauffeurId;
            this.cotisations = cotisations;
            this.creances = creances;
            this.fond = cotisations.stream()
                    .map(LigneCotisation::fondRestituable)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            this.disponible = this.fond;
        }
    }
}
