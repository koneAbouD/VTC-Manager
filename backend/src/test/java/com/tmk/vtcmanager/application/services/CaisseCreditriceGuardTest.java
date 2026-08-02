package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.CaisseCreditriceException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Une caisse d'espèces ne peut pas être créditrice : le tiroir ne rend pas plus
 * que ce qu'il contient. Les autres supports, eux, tolèrent un solde négatif —
 * une banque a un découvert, ce n'est pas une anomalie de saisie.
 */
class CaisseCreditriceGuardTest {

    private static final LocalDate AUJOURD_HUI = LocalDate.now();

    private CompteTresorerieRepository compteRepository;
    private CaisseCreditriceGuard guard;

    @BeforeEach
    void setUp() {
        compteRepository = mock(CompteTresorerieRepository.class);
        guard = new CaisseCreditriceGuard(compteRepository);
    }

    private void compte(TypeCompteTresorerie type, long solde) {
        when(compteRepository.findAvecSoldeALaDate(anyLong(), any()))
                .thenReturn(Optional.of(CompteAvecSolde.builder()
                        .compte(CompteTresorerie.builder()
                                .id(1L).libelle("Caisse espèces").type(type).build())
                        .solde(BigDecimal.valueOf(solde))
                        .build()));
    }

    @Test
    @DisplayName("Un décaissement supérieur au solde de la caisse est refusé")
    void decaissement_superieur_au_solde_refuse() {
        compte(TypeCompteTresorerie.CAISSE, 30_000);

        assertThatThrownBy(() ->
                guard.verifier(1L, BigDecimal.valueOf(50_000), AUJOURD_HUI))
                .isInstanceOf(CaisseCreditriceException.class)
                .hasMessageContaining("Caisse espèces");
    }

    @Test
    @DisplayName("Un décaissement qui vide exactement la caisse passe")
    void decaissement_egal_au_solde_accepte() {
        compte(TypeCompteTresorerie.CAISSE, 50_000);

        assertThatCode(() -> guard.verifier(1L, BigDecimal.valueOf(50_000), AUJOURD_HUI))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Un compte bancaire n'est pas soumis au contrôle : le découvert existe")
    void banque_non_controlee() {
        compte(TypeCompteTresorerie.BANQUE, 10_000);

        assertThatCode(() -> guard.verifier(1L, BigDecimal.valueOf(500_000), AUJOURD_HUI))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Un encaissement ne déclenche jamais le contrôle")
    void encaissement_ignore() {
        compte(TypeCompteTresorerie.CAISSE, 0);

        assertThatCode(() -> guard.verifier(1L, BigDecimal.valueOf(-50_000), AUJOURD_HUI))
                .doesNotThrowAnyException();
        assertThatCode(() -> guard.verifier(1L, BigDecimal.ZERO, AUJOURD_HUI))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Sans compte rattaché, il n'y a rien à contrôler")
    void sans_compte_aucun_controle() {
        assertThatCode(() -> guard.verifier(null, BigDecimal.valueOf(50_000), AUJOURD_HUI))
                .doesNotThrowAnyException();
    }
}
