package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.domain.notification.ApplicationCliente;
import com.tmk.vtcmanager.application.domain.notification.DeviceToken;
import com.tmk.vtcmanager.application.domain.notification.Plateforme;
import com.tmk.vtcmanager.application.ports.persistence.DeviceTokenRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EnregistrerDeviceTokenUseCaseTest {

    private static final String JETON = "fcm-jeton-appareil";

    private DeviceTokenRepository repository;
    private EnregistrerDeviceTokenUseCase useCase;

    @BeforeEach
    void setUp() {
        repository = mock(DeviceTokenRepository.class);
        useCase = new EnregistrerDeviceTokenUseCase(repository);
        when(repository.save(any(DeviceToken.class))).thenAnswer(i -> i.getArgument(0));
    }

    @Test
    void enregistre_un_appareil_inconnu() {
        when(repository.findByToken(JETON)).thenReturn(Optional.empty());

        DeviceToken resultat = useCase.execute(demande("chauffeur-1", ApplicationCliente.CHAUFFEUR));

        assertThat(resultat.getKeycloakUserId()).isEqualTo("chauffeur-1");
        assertThat(resultat.isActif()).isTrue();
        assertThat(resultat.getVuLe()).isNotNull();
    }

    @Test
    void reaffecte_le_jeton_au_nouveau_compte_connecte_sur_le_meme_appareil() {
        // Le téléphone était celui du chauffeur 1 ; le chauffeur 2 s'y connecte.
        // FCM rend le même jeton : la ligne doit changer de propriétaire, sinon
        // le chauffeur 1 continuerait de recevoir ses notifications dessus.
        DeviceToken existant = DeviceToken.builder()
                .id(7L)
                .keycloakUserId("chauffeur-1")
                .token(JETON)
                .plateforme(Plateforme.ANDROID)
                .application(ApplicationCliente.CHAUFFEUR)
                .actif(true)
                .build();
        when(repository.findByToken(JETON)).thenReturn(Optional.of(existant));

        useCase.execute(demande("chauffeur-2", ApplicationCliente.CHAUFFEUR));

        ArgumentCaptor<DeviceToken> capture = ArgumentCaptor.forClass(DeviceToken.class);
        verify(repository).save(capture.capture());
        assertThat(capture.getValue().getId()).isEqualTo(7L);
        assertThat(capture.getValue().getKeycloakUserId()).isEqualTo("chauffeur-2");
    }

    @Test
    void reactive_un_appareil_precedemment_revoque() {
        DeviceToken revoque = DeviceToken.builder()
                .id(9L)
                .keycloakUserId("chauffeur-1")
                .token(JETON)
                .plateforme(Plateforme.ANDROID)
                .application(ApplicationCliente.CHAUFFEUR)
                .actif(false)
                .build();
        when(repository.findByToken(JETON)).thenReturn(Optional.of(revoque));

        DeviceToken resultat = useCase.execute(demande("chauffeur-1", ApplicationCliente.CHAUFFEUR));

        assertThat(resultat.isActif()).isTrue();
    }

    @Test
    void refuse_une_demande_sans_jeton() {
        DeviceToken sansJeton = DeviceToken.builder()
                .keycloakUserId("chauffeur-1")
                .plateforme(Plateforme.ANDROID)
                .application(ApplicationCliente.CHAUFFEUR)
                .build();

        assertThatThrownBy(() -> useCase.execute(sansJeton))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("jeton");
    }

    private DeviceToken demande(String keycloakUserId, ApplicationCliente application) {
        return DeviceToken.builder()
                .keycloakUserId(keycloakUserId)
                .token(JETON)
                .plateforme(Plateforme.ANDROID)
                .application(application)
                .build();
    }
}
