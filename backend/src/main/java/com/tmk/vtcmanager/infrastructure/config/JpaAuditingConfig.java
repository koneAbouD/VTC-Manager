package com.tmk.vtcmanager.infrastructure.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Horodatage automatique des entités, et auteur des écritures financières —
 * voir {@code SecurityAuditorAware}, désigné par {@code auditorAwareRef}.
 */
@Configuration
@EnableJpaAuditing(auditorAwareRef = "securityAuditorAware")
public class JpaAuditingConfig {
}
