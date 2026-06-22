package com.tmk.vtcmanager.infrastructure.config;

import org.flywaydb.core.Flyway;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/**
 * Stratégie Flyway pour les environnements de développement et de test.
 *
 * <p>Appelle {@code repair()} avant {@code migrate()} afin de resynchroniser
 * les checksums dans la table d'historique ({@code flyway_schema_history})
 * lorsqu'un script déjà appliqué est modifié en cours de développement.
 *
 * <p>⚠️ Ne jamais activer en production : le repair écrase les checksums
 * sans vérification de cohérence des données.
 */
@Configuration
@Profile({"dev", "test"})
public class FlywayDevConfig {

    @Bean
    public FlywayMigrationStrategy repairAndMigrate() {
        return (Flyway flyway) -> {
            flyway.repair();
            flyway.migrate();
        };
    }
}
