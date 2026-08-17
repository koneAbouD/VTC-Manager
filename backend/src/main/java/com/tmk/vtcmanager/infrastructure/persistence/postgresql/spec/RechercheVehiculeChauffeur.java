package com.tmk.vtcmanager.infrastructure.persistence.postgresql.spec;

import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.From;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;

import java.util.List;

/**
 * Prédicat de recherche libre commun aux listes rattachées à un véhicule et à
 * un chauffeur (recettes, cotisations, pénalités, contraventions).
 *
 * <p>Le mot-clé est confronté à l'immatriculation du véhicule, au nom et au
 * prénom du chauffeur, ainsi qu'au nom complet dans les deux ordres — « jean
 * dupont » comme « dupont jean » doivent ramener la même ligne.</p>
 *
 * <p>Les jointures sont volontairement en LEFT : une ligne dont le véhicule ou
 * le chauffeur n'est pas renseigné (cas des contraventions) doit rester
 * trouvable par l'autre critère.</p>
 */
public final class RechercheVehiculeChauffeur {

    private RechercheVehiculeChauffeur() {
    }

    /** Vrai si le mot-clé mérite un prédicat (non nul et non vide). */
    public static boolean estRenseignee(String recherche) {
        return recherche != null && !recherche.isBlank();
    }

    /** Motif LIKE dérivé du mot-clé : minuscules, entouré de jokers. */
    public static String motif(String recherche) {
        return "%" + recherche.trim().toLowerCase() + "%";
    }

    /**
     * Construit le prédicat pour {@code recherche}, en joignant lui-même le
     * véhicule et le chauffeur. L'appelant s'assure au préalable que le mot-clé
     * est renseigné ({@link #estRenseignee}).
     *
     * @param root racine (ou jointure) portant les associations {@code vehicule}
     *             et {@code chauffeur}
     */
    public static Predicate predicat(From<?, ?> root, CriteriaBuilder cb, String recherche) {
        Join<?, ?> vehicule = root.join("vehicule", JoinType.LEFT);
        Join<?, ?> chauffeur = root.join("chauffeur", JoinType.LEFT);
        return cb.or(predicats(cb, vehicule, chauffeur, motif(recherche))
                .toArray(new Predicate[0]));
    }

    /**
     * Variante pour les specs qui joignent déjà le véhicule et le chauffeur, ou
     * qui élargissent la recherche à d'autres colonnes : les prédicats sont
     * rendus tels quels, à charge de l'appelant de les combiner en OR avec les
     * siens. Évite de rejoindre deux fois les mêmes tables.
     */
    public static List<Predicate> predicats(CriteriaBuilder cb, From<?, ?> vehicule,
                                            From<?, ?> chauffeur, String motif) {
        var prenom = chauffeur.<String>get("prenom");
        var nom = chauffeur.<String>get("nom");

        return List.of(
                cb.like(cb.lower(vehicule.get("immatriculation")), motif),
                cb.like(cb.lower(nom), motif),
                cb.like(cb.lower(prenom), motif),
                cb.like(cb.lower(cb.concat(cb.concat(prenom, " "), nom)), motif),
                cb.like(cb.lower(cb.concat(cb.concat(nom, " "), prenom)), motif));
    }
}
