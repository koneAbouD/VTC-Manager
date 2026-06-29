package com.tmk.vtcmanager;

import jakarta.annotation.PostConstruct;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.util.TimeZone;

@SpringBootApplication
@EnableScheduling
public class VtcManagerApplication {

    /**
     * Fixe le fuseau horaire métier (Côte d'Ivoire, UTC+0) pour que toute la
     * logique basée sur {@code LocalDate.now()} (statut des indisponibilités,
     * crons, validations de dates) corresponde à la date locale des utilisateurs,
     * indépendamment du fuseau du serveur/conteneur.
     */
    @PostConstruct
    public void initTimeZone() {
        TimeZone.setDefault(TimeZone.getTimeZone("Africa/Abidjan"));
    }

    public static void main(String[] args) {
        SpringApplication.run(VtcManagerApplication.class, args);
    }
}
