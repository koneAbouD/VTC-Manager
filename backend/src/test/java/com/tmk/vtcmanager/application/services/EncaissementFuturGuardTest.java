package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.exception.EncaissementFuturException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Verrou de l'encaissement postdaté : un encaissement constate de l'argent déjà
 * reçu, il ne se date pas de demain. Le passé, lui, reste ouvert — c'est aux
 * verrous de période et de caisse de dire jusqu'où on peut remonter.
 */
class EncaissementFuturGuardTest {

    private final EncaissementFuturGuard guard = new EncaissementFuturGuard();

    @Test
    @DisplayName("Demain est refusé")
    void demain_refuse() {
        LocalDate demain = LocalDate.now().plusDays(1);

        assertThatThrownBy(() -> guard.verifier(demain))
                .isInstanceOf(EncaissementFuturException.class)
                .hasMessageContaining(demain.toString())
                .hasMessageContaining("dans le futur");
    }

    @Test
    @DisplayName("Aujourd'hui passe : c'est le cas courant")
    void aujourdhui_accepte() {
        assertThatCode(() -> guard.verifier(LocalDate.now())).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Le passé n'est pas l'affaire de ce verrou")
    void passe_accepte() {
        // Régulariser la veille reste permis ; ce sont les clôtures qui tranchent.
        assertThatCode(() -> guard.verifier(LocalDate.now().minusDays(1)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Sans date, aucun contrôle")
    void date_nulle_ignoree() {
        assertThatCode(() -> guard.verifier(null)).doesNotThrowAnyException();
    }
}
