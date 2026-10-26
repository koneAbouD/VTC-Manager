package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.UpdateVehiculeCommand;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.exception.FicheModifieeEntreTempsException;
import com.tmk.vtcmanager.application.ports.persistence.BaliseRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.ConfigurationRecetteSynchronizer;
import com.tmk.vtcmanager.application.services.VehiculeStatutHistoriqueService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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
        return commande(prixAchat, null);
    }

    private UpdateVehiculeCommand commande(BigDecimal prixAchat, Long version) {
        // Ordre : …, dateAchat, prixAchat, dureeAmortissementMois, dates…, version
        return new UpdateVehiculeCommand(
                null, null, null, null, null, null, null, null, null, null,
                null, null, null, prixAchat, null, null, null, null, version);
    }

    @Nested
    @DisplayName("Fiche modifiée entre-temps")
    class Version {

        private Vehicule existantEnVersion(long version) {
            Vehicule existant = vehiculeExistant();
            existant.setVersion(version);
            when(vehiculeRepository.findById(1L)).thenReturn(Optional.of(existant));
            return existant;
        }

        @Test
        @DisplayName("une saisie partie d'une version périmée est refusée, rien n'est écrit")
        void versionPerimeeRefusee() {
            existantEnVersion(4L);

            assertThatThrownBy(() -> useCase.execute(1L, commande(new BigDecimal("1"), 3L)))
                    .isInstanceOf(FicheModifieeEntreTempsException.class)
                    .hasMessageContaining("Rouvrez-la");
            verify(vehiculeRepository, never()).save(any());
        }

        @Test
        @DisplayName("une saisie partie de la version actuelle est enregistrée")
        void versionAJourAcceptee() {
            existantEnVersion(4L);

            Vehicule maj = useCase.execute(1L, commande(new BigDecimal("7500000"), 4L));

            assertThat(maj.getPrixAchat()).isEqualByComparingTo("7500000");
        }

        @Test
        @DisplayName("sans version (application d'avant le contrôle), pas de contrôle")
        void sansVersionPasDeControle() {
            existantEnVersion(4L);

            Vehicule maj = useCase.execute(1L, commande(new BigDecimal("7500000"), null));

            assertThat(maj.getPrixAchat()).isEqualByComparingTo("7500000");
        }
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
