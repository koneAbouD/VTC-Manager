package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.ports.persistence.SequenceReferenceRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;

/**
 * Numérotation des pièces : {@code JOURNAL-EXERCICE-NNNNNN}.
 *
 * <p>Une référence comptable doit être continue et chronologique — c'est ce qui
 * permet de prouver qu'aucune pièce n'a été retirée. Le compteur est tenu en
 * base, par journal et par exercice, et repart à 1 à chaque nouvel exercice.
 */
@RequiredArgsConstructor
public class SequenceReferenceService {

    /** Journaux : un compteur indépendant par nature de pièce. */
    public enum Journal {
        /** Encaissement de recette. */
        ENCAISSEMENT("ENC"),
        /** Encaissement de cotisation. */
        COTISATION("COT"),
        /** Encaissement de pénalité. */
        PENALITE("PEN"),
        /** Opération financière saisie manuellement. */
        OPERATION("OPE"),
        /** Dépense de maintenance. */
        MAINTENANCE("MNT"),
        /** Écart constaté en clôture de caisse. */
        CLOTURE("CLO"),
        /** Contre-passation d'une écriture. */
        EXTOURNE("EXT"),
        /** Règlement de contravention. */
        CONTRAVENTION("CTR"),
        /** Reversement d'une contravention à l'État. */
        REVERSEMENT_ETAT("CTV"),
        /** Arrêté de compte chauffeur. */
        ARRETE("ARR"),
        /** Compensation de créance dans un arrêté. */
        COMPENSATION("COMP"),
        /** Restitution de cotisations. */
        RESTITUTION("RES"),
        /** Recette saisie manuellement. */
        RECETTE("REV"),
        /** Dépense saisie manuellement. */
        DEPENSE("DEP"),
        /** Paiement mobile money initié depuis l'app chauffeur. */
        PAIEMENT("PAY");

        private final String code;

        Journal(String code) {
            this.code = code;
        }

        public String code() {
            return code;
        }
    }

    private final SequenceReferenceRepository repository;

    /** Référence suivante du journal, sur l'exercice de la date donnée. */
    public String suivante(Journal journal, LocalDate date) {
        int exercice = (date != null ? date : LocalDate.now()).getYear();
        long numero = repository.suivant(journal.code(), exercice);
        return String.format("%s-%d-%06d", journal.code(), exercice, numero);
    }

    /** Référence suivante du journal, sur l'exercice courant. */
    public String suivante(Journal journal) {
        return suivante(journal, LocalDate.now());
    }
}
