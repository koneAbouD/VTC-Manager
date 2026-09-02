package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.reaffectation.CandidatReaffectation;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.ReaffectationImpossibleException;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Ce qui autorise — ou non — une créance à changer de débiteur.
 *
 * <p>Changer le chauffeur d'une recette ou d'une cotisation ne déplace aucun
 * montant : le véhicule reste l'axe de résultat, seul l'axe de tiers bouge.
 * L'opération est donc légitime même sur une ligne déjà encaissée, là où
 * corriger un montant ne le serait pas. Elle cesse de l'être dès qu'un tiers a
 * été nommé dans un document qu'on ne peut plus reprendre.
 *
 * <p>Les refus se rangent en deux familles, et la distinction n'est pas
 * cosmétique — elle dit <em>quand</em> chacun se calcule :
 * <ul>
 *   <li>ceux qui ne dépendent pas du chauffeur visé (livres fermés, arrêté,
 *       ligne annulée, paiement en vol, pénalité déjà appliquée) se connaissent
 *       dès la lecture de la fiche : c'est {@link #motifBlocage} qui les nomme,
 *       et l'écran s'en sert pour ne pas proposer une action vouée au refus ;</li>
 *   <li>ceux qui dépendent du chauffeur visé (il conduisait ailleurs ce jour-là)
 *       se jugent candidat par candidat : {@link #evaluerCandidats} les rend
 *       tous d'un coup, {@link #verifierChauffeurCible} éprouve celui qu'on a
 *       choisi.</li>
 * </ul>
 *
 * <p>Le même service sert donc le serveur, qui refuse, et le client, qui se
 * tait — un seul endroit à lire pour savoir ce qui est permis, comme
 * {@link VerrouArreteService} le fait déjà pour la restauration.
 */
@RequiredArgsConstructor
public class ReaffectationChauffeurService {

    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter JOUR_COURT = DateTimeFormatter.ofPattern("dd/MM");

    private final VerrouArreteService verrouArreteService;
    private final ArreteCompteRepository arreteCompteRepository;
    private final PaiementRepository paiementRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final LignePenaliteRepository lignePenaliteRepository;

    /**
     * La ligne à déplacer, résumée à ce dont les règles ont besoin.
     *
     * @param nomCotisation porté par la clé d'unicité d'une cotisation ; null
     *                      pour une recette
     */
    public record Cible(TypeDocumentCreance document, Long documentId, Long vehiculeId,
                        LocalDate date, String nomCotisation) {

        public static Cible de(LigneRecette ligne) {
            return new Cible(TypeDocumentCreance.RECETTE, ligne.getId(), ligne.getVehiculeId(),
                    ligne.getDateRecette(), null);
        }

        public static Cible de(LigneCotisation ligne) {
            return new Cible(TypeDocumentCreance.COTISATION, ligne.getId(), ligne.getVehiculeId(),
                    ligne.getDateCotisation(), ligne.getNomCotisation());
        }
    }

    // ── Famille 1 : ce qui ferme la ligne, quel que soit le chauffeur visé ──

    /** Ce qui interdit de réaffecter cette recette, ou null si rien ne s'y oppose. */
    public String motifBlocage(LigneRecette ligne) {
        if (ligne.getStatut() == StatutLigneRecette.ANNULEE) {
            return "Cette recette est annulée : elle n'est due par personne. Restaurez-la"
                    + " d'abord, puis réaffectez-la.";
        }
        String verrou = motifVerrouDate(ligne.getDateRecette());
        if (verrou != null) return verrou;

        if (arreteCompteRepository.existeLigneValidePourDocument(
                TypeDocumentCreance.RECETTE, ligne.getId())) {
            return "Un arrêté de compte a déjà compensé cette recette avec le dépôt d'un"
                    + " chauffeur nommé. Le décompte a été remis : la créance ne peut plus"
                    + " changer de débiteur. Annulez l'arrêté si la ventilation était fausse.";
        }
        if (paiementRepository.existeEnCours(TypeCiblePaiement.RECETTE, ligne.getId())) {
            return "Un paiement mobile money est en cours sur cette recette. Il créera un"
                    + " versement au nom du chauffeur qui l'a lancé : attendez qu'il aboutisse"
                    + " ou qu'il expire.";
        }
        return motifPenaliteBloquante(ligne.getId());
    }

    /** Ce qui interdit de réaffecter cette cotisation, ou null si rien ne s'y oppose. */
    public String motifBlocage(LigneCotisation ligne) {
        if (ligne.getStatut() == StatutLigneCotisation.ANNULEE) {
            return "Cette cotisation est annulée : elle n'est due par personne. Restaurez-la"
                    + " d'abord, puis réaffectez-la.";
        }
        // Le dépôt a été rendu et un décompte nominatif est parti. Le statut et
        // l'arrêté rattaché disent la même chose par deux chemins : une ligne
        // partiellement encaissée reste PARTIELLEMENT_ENCAISSE tout en portant
        // déjà un arrete_id, et c'est ce second chemin qui la rattrape.
        if (ligne.getStatut() == StatutLigneCotisation.RESTITUEE || ligne.getArreteId() != null) {
            return "Un arrêté de compte a déjà restitué tout ou partie de cette cotisation au"
                    + " chauffeur qui l'avait versée. Le décompte a été remis : le dépôt ne peut"
                    + " plus changer de titulaire. Annulez l'arrêté si la ventilation était fausse.";
        }
        String verrou = motifVerrouDate(ligne.getDateCotisation());
        if (verrou != null) return verrou;

        if (paiementRepository.existeEnCours(TypeCiblePaiement.COTISATION, ligne.getId())) {
            return "Un paiement mobile money est en cours sur cette cotisation. Il créera un"
                    + " versement au nom du chauffeur qui l'a lancé : attendez qu'il aboutisse"
                    + " ou qu'il expire.";
        }
        return null;
    }

    /**
     * Les deux arrêtés de date, dans l'ordre où ils se lisent. La ligne ne
     * mouvemente aucune caisse en propre — ce sont ses versements qui le font —
     * mais la doctrine est celle qui interdit déjà de restaurer : ce qu'un
     * procès-verbal a couvert ne bouge plus.
     */
    private String motifVerrouDate(LocalDate date) {
        VerrouArreteService.Verrous verrous = verrouArreteService.verrous();
        if (verrous.autorise(date)) return null;

        LocalDate finPeriode = verrous.finDernierePeriode();
        if (finPeriode != null && !date.isAfter(finPeriode)) {
            return "Le " + date.format(JOUR) + " appartient à une période comptable clôturée :"
                    + " les états du mois ont été arrêtés avec cette créance au compte de son"
                    + " chauffeur, elle ne peut plus en changer.";
        }
        return "La caisse a été arrêtée le " + verrous.derniereClotureCaisse().format(JOUR)
                + " : la journée du " + date.format(JOUR) + " est close, ses créances ne"
                + " changent plus de débiteur.";
    }

    /**
     * Une pénalité de recette non versée qui a déjà produit ses effets ferme la
     * ligne — et la ferme <b>pour tout le monde</b>, d'où sa place ici et non
     * au moment de l'écriture : la fiche doit le savoir avant d'offrir l'action.
     *
     * <p>Le buzzer a sonné pour quelqu'un, l'avertissement lui a été remis,
     * l'argent est entré à son nom : rien de cela ne se transfère. Une pénalité
     * annulée, elle, n'engage plus personne et reste où elle est.
     */
    private String motifPenaliteBloquante(Long ligneRecetteId) {
        return lignePenaliteRepository.findByLigneRecetteId(ligneRecetteId).stream()
                .filter(p -> p.getStatut() != StatutLignePenalite.ANNULEE)
                .filter(p -> p.getStatut() != StatutLignePenalite.EN_ATTENTE || p.aDesVersements())
                .findFirst()
                .map(p -> "Une pénalité de recette non versée adossée à cette recette a déjà"
                        + " produit ses effets (" + libelle(p.getStatut()) + ") : elle s'est"
                        + " appliquée à son chauffeur et ne peut pas changer de main. Annulez-la"
                        + " si elle était injustifiée, puis réaffectez la recette.")
                .orElse(null);
    }

    /**
     * Les pénalités que la recette emmène avec elle : celles restées en attente
     * et sans versement. Les autres ont déjà été écartées par
     * {@link #motifBlocage}, qui refuse la réaffectation entière — cette
     * méthode ne s'appelle donc qu'après lui.
     */
    public List<LignePenalite> penalitesQuiSuivent(Long ligneRecetteId) {
        return lignePenaliteRepository.findByLigneRecetteId(ligneRecetteId).stream()
                .filter(p -> p.getStatut() == StatutLignePenalite.EN_ATTENTE)
                .filter(p -> !p.aDesVersements())
                .toList();
    }

    private static String libelle(StatutLignePenalite statut) {
        return switch (statut) {
            case PARTIELLEMENT_ENCAISSEE -> "partiellement encaissée";
            case ENCAISSEE -> "encaissée";
            case EXECUTEE -> "exécutée";
            case NOTIFIEE -> "notifiée au chauffeur";
            case EN_COURS -> "immobilisation en cours";
            case LEVEE -> "immobilisation levée";
            case EN_ATTENTE -> "des versements enregistrés";
            case ANNULEE -> "annulée";
        };
    }

    /** Refuse la réaffectation de cette recette si quelque chose la ferme. */
    public void verifierLigne(LigneRecette ligne) {
        refuserSiBloque(motifBlocage(ligne));
    }

    /** Refuse la réaffectation de cette cotisation si quelque chose la ferme. */
    public void verifierLigne(LigneCotisation ligne) {
        refuserSiBloque(motifBlocage(ligne));
    }

    private void refuserSiBloque(String motif) {
        if (motif != null) throw new ReaffectationImpossibleException(motif);
    }

    // ── Famille 2 : ce que le chauffeur visé rend impossible ────────────────

    /**
     * Éprouve le chauffeur visé sur la journée de la ligne, et refuse en le
     * disant.
     *
     * <p>Deux obstacles s'y jouent, et le second ne se devine pas :
     * <ol>
     *   <li><b>L'invariant métier</b> — à une date donnée, toutes les lignes
     *       vivantes d'un chauffeur portent le même véhicule. Un chauffeur ne
     *       conduit pas deux voitures le même jour ; lui imputer les créances de
     *       deux véhicules ferait mentir sa balance.</li>
     *   <li><b>La contrainte d'unicité en base</b>, qui ne filtre pas sur le
     *       statut : si le chauffeur visé porte déjà une ligne <em>annulée</em>
     *       sur ce véhicule et ce jour, la mise à jour partirait en violation de
     *       contrainte. Métier, rien ne s'y oppose ; techniquement, si. On le dit
     *       en français plutôt que de laisser remonter l'erreur de la base.</li>
     * </ol>
     */
    public void verifierChauffeurCible(Cible cible, Long chauffeurCibleId) {
        Obstacle obstacle = obstacle(cible, chauffeurCibleId,
                ligneRecetteRepository.findByChauffeurIdAndDateRecette(chauffeurCibleId, cible.date()),
                ligneCotisationRepository.findByChauffeurIdAndDateCotisation(chauffeurCibleId, cible.date()));
        if (obstacle != null) throw new ReaffectationImpossibleException(obstacle.complet());
    }

    /**
     * Juge tous les chauffeurs d'un coup, pour que l'écran montre le conflit
     * <b>avant</b> le choix plutôt qu'au retour du serveur.
     *
     * <p>La journée est lue une seule fois, puis chaque candidat se juge en
     * mémoire : trente chauffeurs éprouvés un par un coûteraient soixante
     * requêtes pour une information qui tient en deux.
     *
     * @param auProgramme chauffeurs attendus au volant de ce véhicule ce jour-là
     */
    public List<CandidatReaffectation> evaluerCandidats(Cible cible, List<Chauffeur> chauffeurs,
                                                        Set<Long> auProgramme, Long chauffeurActuelId) {
        Map<Long, List<LigneRecette>> recettesParChauffeur =
                ligneRecetteRepository.findByDateRecette(cible.date()).stream()
                        .filter(l -> l.getChauffeurId() != null)
                        .collect(Collectors.groupingBy(LigneRecette::getChauffeurId));
        Map<Long, List<LigneCotisation>> cotisationsParChauffeur =
                ligneCotisationRepository.findByDateCotisation(cible.date()).stream()
                        .filter(l -> l.getChauffeurId() != null)
                        .collect(Collectors.groupingBy(LigneCotisation::getChauffeurId));

        List<CandidatReaffectation> candidats = new ArrayList<>();
        for (Chauffeur chauffeur : chauffeurs) {
            Long id = chauffeur.getId();
            if (id == null) continue;

            List<LigneRecette> sesRecettes = recettesParChauffeur.getOrDefault(id, List.of());
            List<LigneCotisation> sesCotisations = cotisationsParChauffeur.getOrDefault(id, List.of());
            boolean actuel = Objects.equals(id, chauffeurActuelId);
            Obstacle obstacle = actuel ? null : obstacle(cible, id, sesRecettes, sesCotisations);

            candidats.add(new CandidatReaffectation(
                    id,
                    nomComplet(chauffeur),
                    auProgramme.contains(id),
                    actuel,
                    obstacle == null,
                    obstacle != null ? obstacle.court()
                            : actuel ? null : etatDuJour(cible, sesRecettes, sesCotisations)));
        }

        // Les conducteurs attendus d'abord, puis l'ordre alphabétique : c'est
        // dans cet ordre que l'utilisateur cherche.
        candidats.sort(Comparator
                .comparing(CandidatReaffectation::actuel).reversed()
                .thenComparing(Comparator.comparing(CandidatReaffectation::auProgramme).reversed())
                .thenComparing(c -> c.nom() == null ? "" : c.nom(), String.CASE_INSENSITIVE_ORDER));
        return candidats;
    }

    /** Ce qu'un obstacle dit : en bref dans une liste, en entier dans un refus. */
    private record Obstacle(String court, String complet) {}

    private Obstacle obstacle(Cible cible, Long chauffeurId,
                              List<LigneRecette> sesRecettes, List<LigneCotisation> sesCotisations) {
        // 1. Un seul véhicule par jour et par chauffeur.
        for (LigneRecette autre : sesRecettes) {
            if (estLaMemeLigne(cible, TypeDocumentCreance.RECETTE, autre.getId())) continue;
            if (autre.getStatut() == StatutLigneRecette.ANNULEE) continue;
            if (Objects.equals(autre.getVehiculeId(), cible.vehiculeId())) continue;
            return conflitVehicule(cible.date(),
                    libelleVehicule(autre.getVehiculeId(), autre.getVehiculeImmatriculation()),
                    "une recette");
        }
        for (LigneCotisation autre : sesCotisations) {
            if (estLaMemeLigne(cible, TypeDocumentCreance.COTISATION, autre.getId())) continue;
            if (autre.getStatut() == StatutLigneCotisation.ANNULEE) continue;
            if (Objects.equals(autre.getVehiculeId(), cible.vehiculeId())) continue;
            return conflitVehicule(cible.date(),
                    libelleVehicule(autre.getVehiculeId(), autre.getVehiculeImmatriculation()),
                    "une cotisation");
        }

        // 2. Le doublon que la contrainte d'unicité refuserait sans rien expliquer.
        if (cible.document() == TypeDocumentCreance.RECETTE) {
            return sesRecettes.stream()
                    .filter(autre -> !Objects.equals(autre.getId(), cible.documentId()))
                    .filter(autre -> Objects.equals(autre.getVehiculeId(), cible.vehiculeId()))
                    .findFirst()
                    .map(autre -> doublon("recette",
                            autre.getStatut() == StatutLigneRecette.ANNULEE, cible.date()))
                    .orElse(null);
        }
        return sesCotisations.stream()
                .filter(autre -> !Objects.equals(autre.getId(), cible.documentId()))
                .filter(autre -> Objects.equals(autre.getVehiculeId(), cible.vehiculeId()))
                .filter(autre -> memeNom(autre.getNomCotisation(), cible.nomCotisation()))
                .findFirst()
                .map(autre -> doublon("cotisation « " + autre.getNomCotisation() + " »",
                        autre.getStatut() == StatutLigneCotisation.ANNULEE, cible.date()))
                .orElse(null);
    }

    /**
     * Ce que le candidat porte déjà ce jour-là. Un chauffeur libre et un
     * chauffeur qui mène déjà ce véhicule sont tous deux éligibles, mais ce
     * n'est pas la même chose à lire avant de choisir.
     */
    private String etatDuJour(Cible cible, List<LigneRecette> sesRecettes,
                              List<LigneCotisation> sesCotisations) {
        long surCeVehicule = sesRecettes.stream()
                .filter(l -> l.getStatut() != StatutLigneRecette.ANNULEE)
                .filter(l -> Objects.equals(l.getVehiculeId(), cible.vehiculeId()))
                .count()
                + sesCotisations.stream()
                .filter(l -> l.getStatut() != StatutLigneCotisation.ANNULEE)
                .filter(l -> Objects.equals(l.getVehiculeId(), cible.vehiculeId()))
                .count();
        if (surCeVehicule == 0) return "Aucune créance le " + cible.date().format(JOUR_COURT);
        return "Déjà " + surCeVehicule + " créance" + (surCeVehicule > 1 ? "s" : "")
                + " sur ce véhicule ce jour-là";
    }

    private boolean estLaMemeLigne(Cible cible, TypeDocumentCreance autreDocument, Long autreId) {
        return cible.document() == autreDocument && Objects.equals(cible.documentId(), autreId);
    }

    private boolean memeNom(String a, String b) {
        return Objects.equals(LigneCotisation.normaliserNom(a), LigneCotisation.normaliserNom(b));
    }

    private String libelleVehicule(Long id, String immatriculation) {
        return immatriculation != null && !immatriculation.isBlank()
                ? immatriculation : "le véhicule n°" + id;
    }

    private Obstacle conflitVehicule(LocalDate date, String vehicule, String quoi) {
        return new Obstacle(
                "Conduisait " + vehicule + " le " + date.format(JOUR_COURT),
                "Ce chauffeur conduisait déjà " + vehicule + " le " + date.format(JOUR)
                        + " (" + quoi + " à son compte). Un chauffeur ne peut pas être affecté à"
                        + " deux véhicules le même jour.");
    }

    private Obstacle doublon(String quoi, boolean annulee, LocalDate date) {
        if (annulee) {
            return new Obstacle(
                    "A une " + quoi + " annulée sur ce véhicule ce jour-là",
                    "Ce chauffeur porte déjà une " + quoi + " annulée sur ce véhicule le "
                            + date.format(JOUR) + ". Restaurez-la plutôt que d'en déplacer une autre :"
                            + " la même ligne ne peut pas exister deux fois.");
        }
        return new Obstacle(
                "A déjà une " + quoi + " sur ce véhicule ce jour-là",
                "Ce chauffeur a déjà une " + quoi + " sur ce véhicule le " + date.format(JOUR)
                        + ". Réaffecter créerait un doublon.");
    }

    private static String nomComplet(Chauffeur chauffeur) {
        String prenom = chauffeur.getPrenom() != null ? chauffeur.getPrenom() : "";
        String nom = chauffeur.getNom() != null ? chauffeur.getNom() : "";
        String complet = (prenom + " " + nom).trim();
        return complet.isEmpty() ? "Chauffeur n°" + chauffeur.getId() : complet;
    }
}
