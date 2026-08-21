package com.tmk.vtcmanager.application.domain.cotisation;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Restituer une cotisation ne doit jamais effacer ce qu'elle doit encore.
 *
 * <p>Un arrêté marquait la ligne RESTITUEE en entier, quel que soit son
 * encaissement : partiellement payée, elle sortait de la balance âgée et la part
 * impayée disparaissait sans qu'aucune écriture ne l'ait éteinte. Le dépôt rendu
 * et la dette du chauffeur sont deux faits distincts.
 */
class LigneCotisationRestitutionTest {

    private LigneCotisation ligne(int du, int encaisse, StatutLigneCotisation statut) {
        return LigneCotisation.builder()
                .id(1L).vehiculeId(10L).chauffeurId(20L)
                .dateCotisation(LocalDate.of(2026, 8, 1)).nomCotisation("Épargne")
                .montantDu(BigDecimal.valueOf(du))
                .montantEncaisse(BigDecimal.valueOf(encaisse))
                .statut(statut)
                .build();
    }

    @Test
    @DisplayName("Le fonds restituable est ce qui a été encaissé, moins ce qui a déjà été rendu")
    void fond_restituable_deduit_les_restitutions_passees() {
        LigneCotisation l = ligne(2_000, 2_000, StatutLigneCotisation.ENCAISSE);
        assertThat(l.fondRestituable()).isEqualByComparingTo("2000");

        l.setMontantRestitue(BigDecimal.valueOf(500));
        assertThat(l.fondRestituable()).isEqualByComparingTo("1500");
    }

    @Test
    @DisplayName("Un encaissement annulé après restitution ne rend pas le fonds négatif")
    void fond_restituable_borne_a_zero() {
        LigneCotisation l = ligne(2_000, 0, StatutLigneCotisation.EN_ATTENTE);
        l.setMontantRestitue(BigDecimal.valueOf(500));

        assertThat(l.fondRestituable()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("Une cotisation soldée passe RESTITUEE quand l'arrêté rend son dépôt")
    void ligne_soldee_devient_restituee() {
        LigneCotisation l = ligne(2_000, 2_000, StatutLigneCotisation.ENCAISSE);

        l.restituer(7L, l.fondRestituable());

        assertThat(l.getStatut()).isEqualTo(StatutLigneCotisation.RESTITUEE);
        assertThat(l.getArreteId()).isEqualTo(7L);
        assertThat(l.getMontantRestitue()).isEqualByComparingTo("2000");
        assertThat(l.fondRestituable()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("Une cotisation à moitié payée reste due : elle ne passe pas RESTITUEE")
    void ligne_partielle_reste_une_creance() {
        LigneCotisation l = ligne(2_000, 500, StatutLigneCotisation.PARTIELLEMENT_ENCAISSE);

        l.restituer(7L, l.fondRestituable());

        assertThat(l.getStatut()).isEqualTo(StatutLigneCotisation.PARTIELLEMENT_ENCAISSE);
        assertThat(l.getMontantRestitue()).isEqualByComparingTo("500");
        // Le dépôt est sorti du fonds, mais les 1 500 restent dus.
        assertThat(l.fondRestituable()).isEqualByComparingTo("0");
        assertThat(l.montantRestant()).isEqualByComparingTo("1500");
    }

    @Test
    @DisplayName("Le solde payé plus tard revient au fonds sans rendre deux fois le premier versement")
    void solde_paye_apres_restitution_partielle() {
        LigneCotisation l = ligne(2_000, 500, StatutLigneCotisation.PARTIELLEMENT_ENCAISSE);
        l.restituer(7L, l.fondRestituable());

        // Le chauffeur solde sa cotisation : le recalcul remet la ligne à jour.
        l.setMontantEncaisse(BigDecimal.valueOf(2_000));
        l.setStatut(StatutLigneCotisation.ENCAISSE);

        assertThat(l.fondRestituable()).isEqualByComparingTo("1500");
        assertThat(l.montantRestant()).isEqualByComparingTo("0");
    }
}
