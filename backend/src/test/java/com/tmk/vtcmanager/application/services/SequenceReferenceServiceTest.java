package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.ports.persistence.SequenceReferenceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Numérotation des pièces {@code JOURNAL-EXERCICE-NNNNNN}. Le format et les
 * codes de journal sont opposables : des pièces déjà émises les portent, et une
 * série comptable ne change pas de préfixe en cours de route.
 */
class SequenceReferenceServiceTest {

    private SequenceReferenceRepository repository;
    private SequenceReferenceService service;

    @BeforeEach
    void setUp() {
        repository = mock(SequenceReferenceRepository.class);
        when(repository.suivant(anyString(), anyInt())).thenReturn(42L);
        service = new SequenceReferenceService(repository);
    }

    @Test
    @DisplayName("La référence combine journal, exercice et numéro sur 6 chiffres")
    void format_reference() {
        String reference = service.suivante(
                SequenceReferenceService.Journal.ENCAISSEMENT, LocalDate.of(2026, 4, 10));

        assertThat(reference).isEqualTo("ENC-2026-000042");
    }

    @Test
    @DisplayName("L'exercice est celui de la date de la pièce, pas celui du jour")
    void exercice_de_la_piece() {
        // Saisie en janvier d'une pièce datée de décembre : elle appartient à
        // l'exercice précédent, dont le compteur est distinct.
        service.suivante(SequenceReferenceService.Journal.OPERATION, LocalDate.of(2025, 12, 31));

        verify(repository).suivant("OPE", 2025);
    }

    @Test
    @DisplayName("Sans date, la pièce est numérotée sur l'exercice courant")
    void exercice_courant_par_defaut() {
        service.suivante(SequenceReferenceService.Journal.DEPENSE);

        verify(repository).suivant("DEP", LocalDate.now().getYear());
    }

    @Test
    @DisplayName("Une date nulle retombe elle aussi sur l'exercice courant")
    void date_nulle() {
        service.suivante(SequenceReferenceService.Journal.RECETTE, null);

        verify(repository).suivant("REV", LocalDate.now().getYear());
    }

    @Test
    @DisplayName("Un numéro à 7 chiffres n'est pas tronqué")
    void numero_au_dela_du_million() {
        when(repository.suivant(anyString(), anyInt())).thenReturn(1_234_567L);

        assertThat(service.suivante(SequenceReferenceService.Journal.ENCAISSEMENT,
                LocalDate.of(2026, 1, 1))).isEqualTo("ENC-2026-1234567");
    }

    /**
     * Les codes sont figés : les changer réécrirait la série de pièces déjà
     * émises. FRN et RGF, notamment, restent ceux du module Fournisseur devenu
     * Partenaire.
     */
    @ParameterizedTest(name = "{0} → {1}")
    @CsvSource({
            "ENCAISSEMENT, ENC", "COTISATION, COT", "PENALITE, PEN", "OPERATION, OPE",
            "MAINTENANCE, MNT", "CLOTURE, CLO", "EXTOURNE, EXT", "CONTRAVENTION, CTR",
            "REVERSEMENT_ETAT, CTV", "ARRETE, ARR", "COMPENSATION, COMP", "RESTITUTION, RES",
            "RECETTE, REV", "DEPENSE, DEP", "PAIEMENT, PAY",
            "PARTENAIRE, FRN", "REGLEMENT_PARTENAIRE, RGF"
    })
    @DisplayName("Les codes de journal sont figés")
    void codes_journaux(SequenceReferenceService.Journal journal, String code) {
        assertThat(journal.code()).isEqualTo(code);
    }

    @Test
    @DisplayName("Chaque journal tient un compteur indépendant")
    void compteurs_independants() {
        LocalDate date = LocalDate.of(2026, 4, 10);
        when(repository.suivant("ENC", 2026)).thenReturn(7L);
        when(repository.suivant("COT", 2026)).thenReturn(3L);

        assertThat(service.suivante(SequenceReferenceService.Journal.ENCAISSEMENT, date))
                .isEqualTo("ENC-2026-000007");
        assertThat(service.suivante(SequenceReferenceService.Journal.COTISATION, date))
                .isEqualTo("COT-2026-000003");
    }
}
