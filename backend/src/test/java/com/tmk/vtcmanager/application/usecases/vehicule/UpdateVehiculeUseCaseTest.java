package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.UpdateVehiculeCommand;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.ports.persistence.BaliseRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.ConfigurationRecetteSynchronizer;
import com.tmk.vtcmanager.application.services.VehiculeStatutHistoriqueService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class UpdateVehiculeUseCaseTest {

    private VehiculeRepository vehiculeRepository;
    private UpdateVehiculeUseCase useCase;

    @BeforeEach
    void setUp() {
        vehiculeRepository = mock(VehiculeRepository.class);
        useCase = new UpdateVehiculeUseCase(
                vehiculeRepository,
                mock(TypeActiviteRepository.class),
                mock(GroupeVehiculeRepository.class),
                mock(BaliseRepository.class),
                mock(ConditionTravailRepository.class),
                mock(ProgrammeTravailRepository.class),
                mock(ConfigurationRecetteSynchronizer.class),
                mock(VehiculeStatutHistoriqueService.class));
        when(vehiculeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    private Vehicule vehiculeExistant() {
        return Vehicule.builder()
                .id(1L)
                .immatriculation("1234-AB-01")
                .statut(VehiculeStatus.DISPONIBLE)
                .build();
    }

    private UpdateVehiculeCommand commandeAvecPrix(BigDecimal prixAchat) {
        // Ordre : …, dateAchat, prixAchat, dureeAmortissementMois, dates…
        return new UpdateVehiculeCommand(
                null, null, null, null, null, null, null, null, null, null,
                null, null, null, prixAchat, null, null, null, null);
    }

    @Test
    void execute_applique_le_prix_achat() {
        when(vehiculeRepository.findById(1L)).thenReturn(Optional.of(vehiculeExistant()));

        Vehicule maj = useCase.execute(1L, commandeAvecPrix(new BigDecimal("7500000")));

        assertThat(maj.getPrixAchat()).isEqualByComparingTo("7500000");
    }

    @Test
    void execute_conserve_le_prix_existant_quand_non_fourni() {
        Vehicule existant = vehiculeExistant();
        existant.setPrixAchat(new BigDecimal("5000000"));
        when(vehiculeRepository.findById(1L)).thenReturn(Optional.of(existant));

        Vehicule maj = useCase.execute(1L, commandeAvecPrix(null));

        assertThat(maj.getPrixAchat()).isEqualByComparingTo("5000000");
    }
}
