package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@DisplayName("Dépôts de cotisations détenus")
class GetDepotsCotisationsUseCaseTest {

    private final CompteCourantRepository repository = mock(CompteCourantRepository.class);
    private final GetDepotsCotisationsUseCase useCase = new GetDepotsCotisationsUseCase(repository);

    @Test
    @DisplayName("lit le fonds détenu au jour même")
    void fondsDuJour() {
        when(repository.fondsCotisationsALaDate(LocalDate.now())).thenReturn(new BigDecimal("420000"));

        assertThat(useCase.executer()).isEqualByComparingTo("420000");
    }

    @Test
    @DisplayName("un fonds négatif (données incohérentes) n'est jamais présenté comme dette")
    void jamaisNegatif() {
        when(repository.fondsCotisationsALaDate(LocalDate.now())).thenReturn(new BigDecimal("-50"));

        assertThat(useCase.executer()).isEqualByComparingTo("0");
    }
}
