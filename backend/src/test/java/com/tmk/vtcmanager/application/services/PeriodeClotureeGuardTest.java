package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Verrou du mois clos : une écriture datée dans une période déjà arrêtée ferait
 * mentir un bilan déjà publié. La borne est le dernier jour de la période — le
 * lendemain doit passer, le jour même non.
 */
class PeriodeClotureeGuardTest {

    private CloturePeriodeRepository cloturePeriodeRepository;
    private PeriodeClotureeGuard guard;

    @BeforeEach
    void setUp() {
        cloturePeriodeRepository = mock(CloturePeriodeRepository.class);
        guard = new PeriodeClotureeGuard(cloturePeriodeRepository);
    }

    /** Dernière période close : mars 2026, donc arrêtée au 31/03. */
    private void derniereCloture() {
        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.of(
                CloturePeriode.builder().id(1L).annee(2026).mois(3).build()));
    }

    @Test
    @DisplayName("Une écriture dans la période close est rejetée")
    void dans_periode_close_rejetee() {
        derniereCloture();

        assertThatThrownBy(() -> guard.verifier(LocalDate.of(2026, 3, 15)))
                .isInstanceOf(PeriodeClotureeException.class);
    }

    @Test
    @DisplayName("Une écriture le dernier jour de la période close est rejetée")
    void dernier_jour_inclus() {
        derniereCloture();

        assertThatThrownBy(() -> guard.verifier(LocalDate.of(2026, 3, 31)))
                .isInstanceOf(PeriodeClotureeException.class);
    }

    @Test
    @DisplayName("Une écriture antérieure à la période close est rejetée elle aussi")
    void anterieure_rejetee() {
        derniereCloture();

        assertThatThrownBy(() -> guard.verifier(LocalDate.of(2025, 12, 20)))
                .isInstanceOf(PeriodeClotureeException.class);
    }

    @Test
    @DisplayName("Le lendemain de la clôture rouvre la saisie")
    void lendemain_accepte() {
        derniereCloture();

        assertThatCode(() -> guard.verifier(LocalDate.of(2026, 4, 1))).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Sans aucune clôture, toute date passe")
    void aucune_cloture() {
        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.empty());

        assertThatCode(() -> guard.verifier(LocalDate.of(2020, 1, 1))).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Une écriture sans date n'est pas contrôlée")
    void date_nulle_ignoree() {
        assertThatCode(() -> guard.verifier(null)).doesNotThrowAnyException();
    }
}
