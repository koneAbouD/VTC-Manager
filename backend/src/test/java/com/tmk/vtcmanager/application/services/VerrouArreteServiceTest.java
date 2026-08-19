package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Ce que les arrêtés interdisent de rouvrir.
 *
 * <p>Deux verrous, de portée différente : la clôture de période fige un mois
 * entier pour l'entreprise ; la clôture de caisse arrête une journée. Le second
 * mord souvent plus tôt que le premier — une caisse se compte chaque soir, un
 * mois se clôture une fois — et c'est lui qui, en pratique, ferme la porte le
 * lendemain d'une annulation.
 */
class VerrouArreteServiceTest {

    private static final LocalDate LE_10_AOUT = LocalDate.of(2026, 8, 10);

    private CloturePeriodeRepository cloturePeriodeRepository;
    private ClotureCaisseRepository clotureCaisseRepository;
    private VerrouArreteService service;

    @BeforeEach
    void setUp() {
        cloturePeriodeRepository = mock(CloturePeriodeRepository.class);
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.empty());
        when(clotureCaisseRepository.findDerniereDateClotureToutesCaisses())
                .thenReturn(Optional.empty());
        service = new VerrouArreteService(cloturePeriodeRepository, clotureCaisseRepository);
    }

    /** Dernier mois clôturé : la période court jusqu'à son dernier jour. */
    private void moisCloture(int annee, int mois) {
        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.of(
                CloturePeriode.builder().annee(annee).mois(mois).build()));
    }

    private void caisseCompteeLe(LocalDate date) {
        when(clotureCaisseRepository.findDerniereDateClotureToutesCaisses())
                .thenReturn(Optional.of(date));
    }

    @Test
    @DisplayName("Sans aucun arrêté, tout reste restaurable")
    void aucun_arrete() {
        assertThat(service.estRestaurable(LE_10_AOUT)).isTrue();
    }

    @Test
    @DisplayName("Un mois clôturé ferme les jours qu'il couvre")
    void periode_close() {
        moisCloture(2026, 8);

        assertThat(service.estRestaurable(LE_10_AOUT)).isFalse();
        assertThatThrownBy(() -> service.verifier(LE_10_AOUT))
                .isInstanceOf(EcritureFigeeException.class)
                .hasMessageContaining("période comptable");
    }

    @Test
    @DisplayName("Un mois clôturé laisse ouverts les jours postérieurs")
    void apres_la_periode_close() {
        moisCloture(2026, 7);

        assertThat(service.estRestaurable(LE_10_AOUT)).isTrue();
    }

    @Test
    @DisplayName("Une caisse comptée le jour même ferme la journée")
    void caisse_comptee_le_jour_meme() {
        caisseCompteeLe(LE_10_AOUT);

        assertThat(service.estRestaurable(LE_10_AOUT)).isFalse();
        assertThatThrownBy(() -> service.verifier(LE_10_AOUT))
                .isInstanceOf(EcritureFigeeException.class)
                .hasMessageContaining("caisse");
    }

    @Test
    @DisplayName("Une caisse comptée depuis ferme aussi les jours antérieurs")
    void caisse_comptee_depuis() {
        caisseCompteeLe(LocalDate.of(2026, 8, 15));

        assertThat(service.estRestaurable(LE_10_AOUT)).isFalse();
    }

    @Test
    @DisplayName("Une caisse comptée avant ne ferme pas les jours suivants")
    void caisse_comptee_avant() {
        caisseCompteeLe(LocalDate.of(2026, 8, 9));

        assertThat(service.estRestaurable(LE_10_AOUT)).isTrue();
    }

    @Test
    @DisplayName("Sans date, rien n'est verrouillé")
    void sans_date() {
        moisCloture(2026, 12);

        assertThat(service.estRestaurable(null)).isTrue();
        service.verifier(null);
    }
}
