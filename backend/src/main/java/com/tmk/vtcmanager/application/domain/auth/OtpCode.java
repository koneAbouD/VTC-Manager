package com.tmk.vtcmanager.application.domain.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Code OTP à usage unique pour l'authentification passwordless de l'app chauffeur.
 * Le code en clair n'est jamais stocké : seul {@code codeHash} l'est.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OtpCode {

    private Long id;
    private String telephone;
    private String codeHash;
    private LocalDateTime expiresAt;
    private int tentatives;
    private boolean consomme;
    private LocalDateTime createdAt;

    public boolean estExpire(LocalDateTime maintenant) {
        return expiresAt == null || maintenant.isAfter(expiresAt);
    }

    public boolean estUtilisable(LocalDateTime maintenant, int maxTentatives) {
        return !consomme && tentatives < maxTentatives && !estExpire(maintenant);
    }
}
