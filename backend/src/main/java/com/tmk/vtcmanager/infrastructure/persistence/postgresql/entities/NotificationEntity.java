package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.notification.TypeNotification;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = NotificationEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "notifications";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "destinataire_keycloak_id", nullable = false, length = 36)
    private String destinataireKeycloakId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private TypeNotification type;

    @Column(nullable = false, length = 120)
    private String titre;

    @Column(nullable = false, length = 300)
    private String corps;

    @Column(length = 300)
    private String detail;

    @Column(name = "entite_type", length = 40)
    private String entiteType;

    @Column(name = "entite_id")
    private Long entiteId;

    @Column(name = "cle_groupe", length = 60)
    private String cleGroupe;

    @Column(nullable = false)
    private boolean lue;

    @Column(name = "lue_le")
    private LocalDateTime lueLe;

    @Column(name = "envoyee_le")
    private LocalDateTime envoyeeLe;
}
