package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TransfertTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.CaisseClotureeException;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.exception.TransfertInvalideException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.TransfertTresorerieRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CaisseCreditriceGuard;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Transfert entre deux comptes de trésorerie (dépôt d'espèces sur le
 * portefeuille mobile, retrait bancaire…). Les deux comptes bougent : aucun ne
 * doit être déjà compté ce jour-là, et la source ne peut pas rendre plus
 * qu'elle ne détient.
 */
class CreateTransfertUseCaseTest {

    private static final Long SOURCE = 1L;
    private static final Long DESTINATION = 2L;
    private static final LocalDate JOUR = LocalDate.of(2026, 4, 10);

    private TransfertTresorerieRepository transfertRepository;
    private CompteTresorerieRepository compteTresorerieRepository;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private CaisseClotureeGuard caisseClotureeGuard;
    private CaisseCreditriceGuard caisseCreditriceGuard;
    private CreateTransfertUseCase useCase;

    @BeforeEach
    void setUp() {
        transfertRepository = mock(TransfertTresorerieRepository.class);
        compteTresorerieRepository = mock(CompteTresorerieRepository.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        caisseClotureeGuard = mock(CaisseClotureeGuard.class);
        caisseCreditriceGuard = mock(CaisseCreditriceGuard.class);

        when(compteTresorerieRepository.findById(anyLong())).thenAnswer(inv ->
                Optional.of(CompteTresorerie.builder()
                        .id(inv.getArgument(0)).type(TypeCompteTresorerie.CAISSE).build()));
        when(transfertRepository.save(any())).thenAnswer(inv -> {
            TransfertTresorerie t = inv.getArgument(0);
            t.setId(400L);
            return t;
        });

        useCase = new CreateTransfertUseCase(transfertRepository, compteTresorerieRepository,
                periodeClotureeGuard, caisseClotureeGuard, caisseCreditriceGuard);
    }

    private TransfertTresorerie transfert(Long source, Long destination, Integer montant, LocalDate date) {
        return TransfertTresorerie.builder()
                .compteSourceId(source).compteDestinationId(destination)
                .montant(montant == null ? null : BigDecimal.valueOf(montant))
                .dateTransfert(date).commentaire("dépôt du soir")
                .build();
    }

    @Test
    @DisplayName("Un transfert valide est enregistré")
    void transfert_nominal() {
        TransfertTresorerie saved = useCase.executer(transfert(SOURCE, DESTINATION, 100_000, JOUR));

        assertThat(saved.getId()).isEqualTo(400L);
        assertThat(saved.getMontant()).isEqualByComparingTo("100000");
    }

    @Test
    @DisplayName("Sans date, le transfert porte sur aujourd'hui")
    void date_par_defaut() {
        TransfertTresorerie saved = useCase.executer(transfert(SOURCE, DESTINATION, 100_000, null));

        assertThat(saved.getDateTransfert()).isEqualTo(LocalDate.now());
    }

    @Test
    @DisplayName("Un montant nul ou négatif est refusé")
    void montant_invalide() {
        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, DESTINATION, 0, JOUR)))
                .isInstanceOf(TransfertInvalideException.class);
        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, DESTINATION, -5_000, JOUR)))
                .isInstanceOf(TransfertInvalideException.class);
        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, DESTINATION, null, JOUR)))
                .isInstanceOf(TransfertInvalideException.class);
        verify(transfertRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un transfert d'un compte vers lui-même est refusé")
    void comptes_identiques() {
        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, SOURCE, 100_000, JOUR)))
                .isInstanceOf(TransfertInvalideException.class)
                .hasMessageContaining("distincts");
    }

    @Test
    @DisplayName("Un compte manquant est refusé")
    void compte_manquant() {
        assertThatThrownBy(() -> useCase.executer(transfert(null, DESTINATION, 100_000, JOUR)))
                .isInstanceOf(TransfertInvalideException.class);
        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, null, 100_000, JOUR)))
                .isInstanceOf(TransfertInvalideException.class);
    }

    @Test
    @DisplayName("Un compte inexistant est refusé")
    void compte_introuvable() {
        when(compteTresorerieRepository.findById(DESTINATION)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, DESTINATION, 100_000, JOUR)))
                .isInstanceOf(CompteTresorerieNotFoundException.class);
    }

    @Test
    @DisplayName("Un transfert dans une période close est refusé")
    void periode_close() {
        doThrow(new PeriodeClotureeException(JOUR)).when(periodeClotureeGuard).verifier(JOUR);

        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, DESTINATION, 100_000, JOUR)))
                .isInstanceOf(PeriodeClotureeException.class);
        verify(transfertRepository, never()).save(any());
    }

    @Test
    @DisplayName("Les deux comptes sont contrôlés contre un comptage déjà fait")
    void les_deux_caisses_controlees() {
        useCase.executer(transfert(SOURCE, DESTINATION, 100_000, JOUR));

        verify(caisseClotureeGuard).verifier(SOURCE, JOUR);
        verify(caisseClotureeGuard).verifier(DESTINATION, JOUR);
    }

    @Test
    @DisplayName("Un transfert depuis une caisse déjà comptée est refusé")
    void source_deja_comptee() {
        doThrow(new CaisseClotureeException(JOUR, JOUR))
                .when(caisseClotureeGuard).verifier(SOURCE, JOUR);

        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, DESTINATION, 100_000, JOUR)))
                .isInstanceOf(CaisseClotureeException.class);
    }

    @Test
    @DisplayName("Seule la source est contrôlée contre le découvert")
    void seule_la_source_est_degarnie() {
        useCase.executer(transfert(SOURCE, DESTINATION, 100_000, JOUR));

        verify(caisseCreditriceGuard).verifier(SOURCE, BigDecimal.valueOf(100_000), JOUR);
        verify(caisseCreditriceGuard, never()).verifier(
                org.mockito.ArgumentMatchers.eq(DESTINATION), any(), any());
    }

    @Test
    @DisplayName("Un transfert supérieur au solde de la source est refusé")
    void source_insuffisante() {
        doThrow(new IllegalStateException("solde insuffisant"))
                .when(caisseCreditriceGuard).verifier(any(), any(), any());

        assertThatThrownBy(() -> useCase.executer(transfert(SOURCE, DESTINATION, 100_000, JOUR)))
                .isInstanceOf(IllegalStateException.class);
        verify(transfertRepository, never()).save(any());
    }
}
