package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.notification.ApplicationCliente;
import com.tmk.vtcmanager.application.domain.notification.Plateforme;
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
@Table(name = DeviceTokenEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeviceTokenEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "device_tokens";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "keycloak_user_id", nullable = false, length = 36)
    private String keycloakUserId;

    @Column(nullable = false, unique = true, length = 512)
    private String token;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Plateforme plateforme;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 15)
    private ApplicationCliente application;

    @Column(nullable = false)
    private boolean actif;

    @Column(name = "vu_le")
    private LocalDateTime vuLe;
}
