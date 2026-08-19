package com.tmk.vtcmanager.application.exception;

import java.util.List;

/**
 * Refus de figer un mois, avec de quoi le lever.
 *
 * <p>Un refus de clôture n'est pas une fin : c'est une liste de choses à faire.
 * L'exception porte donc deux renseignements que le seul message ne donnait
 * pas — le {@link Motif}, dont l'écran tire l'action à proposer plutôt que de
 * deviner à partir du texte, et l'énumération de <em>tous</em> les obstacles.
 *
 * <p>Les signaler un par un obligeait à relancer la clôture autant de fois
 * qu'il y avait de comptages manquants, chaque essai n'en révélant qu'un.
 */
public class PeriodeNonCloturableException extends RuntimeException {

    /** Ce qui s'oppose à la clôture, dit en un mot que le client peut traiter. */
    public enum Motif {
        /** Le mois n'est pas fini : les écritures du jour doivent rester possibles. */
        MOIS_NON_ECHU,
        PERIODE_DEJA_CLOTUREE,
        /** Un mois antérieur reste ouvert : le verrou ne saute pas de mois. */
        PERIODE_NON_CONTIGUE,
        /** Un compte au moins n'a pas été contrôlé dans le mois. */
        CAISSE_NON_COMPTEE,
        /** Un écart au moins attend encore une décision. */
        ECART_NON_IMPUTE
    }

    private final Motif motif;

    /**
     * Tout ce qui reste à régler, une phrase par obstacle. Vide quand le refus
     * tient à la période elle-même : le message dit alors tout.
     */
    private final List<String> obstacles;

    public PeriodeNonCloturableException(Motif motif, String message) {
        this(motif, message, List.of());
    }

    public PeriodeNonCloturableException(Motif motif, String message, List<String> obstacles) {
        super(message);
        this.motif = motif;
        this.obstacles = obstacles == null ? List.of() : List.copyOf(obstacles);
    }

    public Motif getMotif() {
        return motif;
    }

    public List<String> getObstacles() {
        return obstacles;
    }
}
