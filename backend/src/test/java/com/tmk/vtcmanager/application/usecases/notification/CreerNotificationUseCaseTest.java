package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.TextesNotification;
import com.tmk.vtcmanager.application.domain.notification.TypeNotification;
import com.tmk.vtcmanager.application.ports.notification.NotificationEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.NotificationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class CreerNotificationUseCaseTest {

    private static final String DESTINATAIRE = "sub-chauffeur";
    private static final String CLE = "ENCAISSEMENT:9:2026-08-03";
    private static final TextesNotification CUMUL =
            new TextesNotification("Versements enregistrés", "Vos versements ont bien été enregistrés.");

    private NotificationRepository repository;
    private NotificationEventPublisher eventPublisher;
    private CreerNotificationUseCase useCase;

    @BeforeEach
    void setUp() {
        repository = mock(NotificationRepository.class);
        eventPublisher = mock(NotificationEventPublisher.class);
        useCase = new CreerNotificationUseCase(repository, eventPublisher);
        when(repository.save(any(Notification.class))).thenAnswer(i -> {
            Notification n = i.getArgument(0);
            if (n.getId() == null) n.setId(1L);
            return n;
        });
        when(repository.findNonLueParCleGroupe(anyString(), anyString(), any(LocalDateTime.class)))
                .thenReturn(Optional.empty());
    }

    @Test
    void enregistre_et_demande_l_envoi_quand_rien_ne_precede() {
        useCase.execute(notification(CLE), CUMUL);

        verify(eventPublisher).publierNotificationCreee(1L);
    }

    @Test
    void reecrit_la_notification_du_meme_geste_au_lieu_d_en_ajouter_une() {
        Notification precedente = notification(CLE);
        precedente.setId(7L);
        precedente.setTitre("Versement enregistré");
        precedente.setCorps("Votre versement de recette du 02/08 a bien été enregistré.");
        when(repository.findNonLueParCleGroupe(anyString(), anyString(), any(LocalDateTime.class)))
                .thenReturn(Optional.of(precedente));

        useCase.execute(notification(CLE), CUMUL);

        ArgumentCaptor<Notification> capteur = ArgumentCaptor.forClass(Notification.class);
        verify(repository).save(capteur.capture());
        assertThat(capteur.getValue().getId()).isEqualTo(7L);
        assertThat(capteur.getValue().getTitre()).isEqualTo("Versements enregistrés");
        assertThat(capteur.getValue().getCorps()).isEqualTo("Vos versements ont bien été enregistrés.");
    }

    @Test
    void empile_les_details_au_lieu_de_les_remplacer() {
        Notification precedente = notification(CLE);
        precedente.setId(7L);
        precedente.setDetail("KOUAME Jean — AB-123-CD · recette du 03/08 : 15 000 FCFA. Solde à jour.");
        when(repository.findNonLueParCleGroupe(anyString(), anyString(), any(LocalDateTime.class)))
                .thenReturn(Optional.of(precedente));

        Notification seconde = notification(CLE);
        seconde.setDetail("KOUAME Jean — AB-123-CD · Assurance du 03/08 : 2 000 FCFA. Solde à jour.");
        useCase.execute(seconde, CUMUL);

        // Le corps dit qu'il y a eu plusieurs versements ; le détail dit
        // lesquels — sinon le regroupement effacerait la moitié de l'information.
        ArgumentCaptor<Notification> capteur = ArgumentCaptor.forClass(Notification.class);
        verify(repository).save(capteur.capture());
        assertThat(capteur.getValue().getDetail())
                .contains("recette du 03/08")
                .contains("Assurance du 03/08");
    }

    @Test
    void tronque_un_detail_trop_long_plutot_que_de_faire_echouer_l_operation() {
        Notification trop = notification(null);
        trop.setDetail("x".repeat(400));

        useCase.execute(trop);

        ArgumentCaptor<Notification> capteur = ArgumentCaptor.forClass(Notification.class);
        verify(repository).save(capteur.capture());
        // La colonne accepte 300 caractères, et un versement ne saurait échouer
        // parce que son récit est trop long.
        assertThat(capteur.getValue().getDetail()).hasSize(300).endsWith("…");
    }

    @Test
    void ne_fait_pas_sonner_le_telephone_une_seconde_fois_pour_le_meme_geste() {
        Notification precedente = notification(CLE);
        precedente.setId(7L);
        when(repository.findNonLueParCleGroupe(anyString(), anyString(), any(LocalDateTime.class)))
                .thenReturn(Optional.of(precedente));

        useCase.execute(notification(CLE), CUMUL);

        verify(eventPublisher, never()).publierNotificationCreee(anyLong());
    }

    @Test
    void sans_cle_de_groupe_chaque_notification_vit_sa_vie() {
        useCase.execute(notification(null), CUMUL);

        verify(repository, never()).findNonLueParCleGroupe(anyString(), anyString(), any(LocalDateTime.class));
        verify(eventPublisher).publierNotificationCreee(1L);
    }

    @Test
    void sans_redaction_de_cumul_le_regroupement_ne_s_applique_pas() {
        useCase.execute(notification(CLE));

        verify(repository, never()).findNonLueParCleGroupe(anyString(), anyString(), any(LocalDateTime.class));
        verify(eventPublisher).publierNotificationCreee(1L);
    }

    private static Notification notification(String cleGroupe) {
        return Notification.builder()
                .destinataireKeycloakId(DESTINATAIRE)
                .type(TypeNotification.RECETTE_ENCAISSEE)
                .titre("Versement enregistré")
                .corps("Votre versement de recette du 03/08 a bien été enregistré.")
                .cleGroupe(cleGroupe)
                .build();
    }
}
