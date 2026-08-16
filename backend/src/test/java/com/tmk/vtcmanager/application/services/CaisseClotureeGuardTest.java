package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.exception.CaisseClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Verrou de la journée comptée : le procès-verbal d'un comptage n'a de valeur
 * que si rien ne bouge derrière lui. Le verrou est par compte — figer une
 * caisse ne doit pas figer le portefeuille mobile money.
 */
class CaisseClotureeGuardTest {

    private static final Long CAISSE = 1L;
    private static final LocalDate COMPTAGE = LocalDate.of(2026, 4, 10);

    private ClotureCaisseRepository clotureCaisseRepository;
    private CaisseClotureeGuard guard;

    @BeforeEach
    void setUp() {
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        when(clotureCaisseRepository.findDerniereDateCloture(CAISSE)).thenReturn(Optional.of(COMPTAGE));
        guard = new CaisseClotureeGuard(clotureCaisseRepository);
    }

    @Test
    @DisplayName("Une écriture le jour du dernier comptage est rejetée")
    void jour_du_comptage_rejete() {
        assertThatThrownBy(() -> guard.verifier(CAISSE, COMPTAGE))
                .isInstanceOf(CaisseClotureeException.class);
    }

    @Test
    @DisplayName("Une écriture antérieure au comptage est rejetée")
    void anterieure_rejetee() {
        assertThatThrownBy(() -> guard.verifier(CAISSE, COMPTAGE.minusDays(3)))
                .isInstanceOf(CaisseClotureeException.class);
    }

    @Test
    @DisplayName("Le lendemain du comptage, la saisie reprend")
    void lendemain_accepte() {
        assertThatCode(() -> guard.verifier(CAISSE, COMPTAGE.plusDays(1))).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Un compte jamais compté n'est pas verrouillé")
    void compte_jamais_compte() {
        when(clotureCaisseRepository.findDerniereDateCloture(2L)).thenReturn(Optional.empty());

        assertThatCode(() -> guard.verifier(2L, LocalDate.of(2020, 1, 1))).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Sans compte ou sans date, aucun contrôle n'est effectué")
    void parametres_nuls_ignores() {
        assertThatCode(() -> guard.verifier(null, COMPTAGE)).doesNotThrowAnyException();
        assertThatCode(() -> guard.verifier(CAISSE, null)).doesNotThrowAnyException();

        // Le verrou ne doit surtout pas interroger la base pour rien.
        verify(clotureCaisseRepository, never()).findDerniereDateCloture(anyLong());
    }
}
