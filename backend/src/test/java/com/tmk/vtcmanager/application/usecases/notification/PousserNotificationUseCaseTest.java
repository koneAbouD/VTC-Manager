package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.domain.notification.ApplicationCliente;
import com.tmk.vtcmanager.application.domain.notification.DeviceToken;
import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.Plateforme;
import com.tmk.vtcmanager.application.domain.notification.ResultatEnvoi;
import com.tmk.vtcmanager.application.domain.notification.TypeNotification;
import com.tmk.vtcmanager.application.ports.notification.PushNotificationPort;
import com.tmk.vtcmanager.application.ports.persistence.DeviceTokenRepository;
import com.tmk.vtcmanager.application.ports.persistence.NotificationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PousserNotificationUseCaseTest {

    private NotificationRepository notificationRepository;
    private DeviceTokenRepository deviceTokenRepository;
    private PushNotificationPort pushNotificationPort;
    private PousserNotificationUseCase useCase;

    @BeforeEach
    void setUp() {
        notificationRepository = mock(NotificationRepository.class);
        deviceTokenRepository = mock(DeviceTokenRepository.class);
        pushNotificationPort = mock(PushNotificationPort.class);
        useCase = new PousserNotificationUseCase(
                notificationRepository, deviceTokenRepository, pushNotificationPort);
        when(notificationRepository.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));
    }

    @Test
    void desactive_les_jetons_rejetes_par_fcm() {
        donneUneNotificationAvecAppareils("actif", "perime");
        when(pushNotificationPort.envoyer(anyList(), any(Notification.class)))
                .thenReturn(new ResultatEnvoi(1, 1, List.of("perime")));

        useCase.execute(1L);

        verify(deviceTokenRepository).desactiverTokens(List.of("perime"));
    }

    @Test
    void ne_desactive_rien_quand_tout_passe() {
        donneUneNotificationAvecAppareils("actif");
        when(pushNotificationPort.envoyer(anyList(), any(Notification.class)))
                .thenReturn(new ResultatEnvoi(1, 0, List.of()));

        useCase.execute(1L);

        verify(deviceTokenRepository, never()).desactiverTokens(anyList());
    }

    @Test
    void horodate_l_envoi_seulement_si_au_moins_un_appareil_a_recu() {
        donneUneNotificationAvecAppareils("actif");
        when(pushNotificationPort.envoyer(anyList(), any(Notification.class)))
                .thenReturn(new ResultatEnvoi(1, 0, List.of()));

        useCase.execute(1L);

        ArgumentCaptor<Notification> capture = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).save(capture.capture());
        assertThat(capture.getValue().getEnvoyeeLe()).isNotNull();
    }

    @Test
    void n_horodate_pas_un_envoi_entierement_echoue() {
        donneUneNotificationAvecAppareils("actif");
        when(pushNotificationPort.envoyer(anyList(), any(Notification.class)))
                .thenReturn(new ResultatEnvoi(0, 1, List.of()));

        useCase.execute(1L);

        verify(notificationRepository, never()).save(any(Notification.class));
    }

    @Test
    void n_appelle_pas_fcm_sans_appareil_enregistre() {
        donneUneNotificationAvecAppareils();

        useCase.execute(1L);

        verify(pushNotificationPort, never()).envoyer(anyList(), any(Notification.class));
    }

    @Test
    void ignore_une_notification_introuvable() {
        when(notificationRepository.findById(404L)).thenReturn(Optional.empty());

        useCase.execute(404L);

        verify(pushNotificationPort, never()).envoyer(anyList(), any(Notification.class));
    }

    private void donneUneNotificationAvecAppareils(String... tokens) {
        Notification notification = Notification.builder()
                .id(1L)
                .destinataireKeycloakId("chauffeur-1")
                .type(TypeNotification.PENALITE_APPLIQUEE)
                .titre("Nouvelle pénalité")
                .corps("Une pénalité a été portée à votre compte.")
                .build();
        when(notificationRepository.findById(1L)).thenReturn(Optional.of(notification));
        when(deviceTokenRepository.findActifsByKeycloakUserId("chauffeur-1"))
                .thenReturn(List.of(tokens).stream().map(this::appareil).toList());
    }

    private DeviceToken appareil(String token) {
        return DeviceToken.builder()
                .token(token)
                .keycloakUserId("chauffeur-1")
                .plateforme(Plateforme.ANDROID)
                .application(ApplicationCliente.CHAUFFEUR)
                .actif(true)
                .build();
    }
}
