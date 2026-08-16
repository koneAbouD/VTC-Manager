package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Rattachement d'une opération à un compte de trésorerie : compte explicite
 * s'il est fourni, sinon compte par défaut du type déduit du mode de paiement.
 * L'absence de compte configuré n'est pas une erreur — les opérations
 * antérieures à la trésorerie n'en portent aucun.
 */
class CompteTresorerieResolverTest {

    private static final CompteTresorerie CAISSE = CompteTresorerie.builder()
            .id(1L).libelle("Caisse espèces").type(TypeCompteTresorerie.CAISSE).build();
    private static final CompteTresorerie WAVE = CompteTresorerie.builder()
            .id(2L).libelle("Wave").type(TypeCompteTresorerie.MOBILE_MONEY).build();

    private CompteTresorerieRepository compteTresorerieRepository;
    private CompteTresorerieResolver resolver;

    @BeforeEach
    void setUp() {
        compteTresorerieRepository = mock(CompteTresorerieRepository.class);
        resolver = new CompteTresorerieResolver(compteTresorerieRepository);
    }

    @Test
    @DisplayName("Le compte explicitement fourni l'emporte sur le mode de paiement")
    void compte_explicite_prioritaire() {
        when(compteTresorerieRepository.findById(2L)).thenReturn(Optional.of(WAVE));

        // Espèces déposées sur le portefeuille mobile : le compte choisi prime.
        assertThat(resolver.resoudre(2L, ModePaiement.ESPECES)).isEqualTo(2L);
        verify(compteTresorerieRepository, never()).findParDefautByType(any());
    }

    @Test
    @DisplayName("Un compte explicite introuvable est une erreur, pas un repli silencieux")
    void compte_explicite_introuvable() {
        when(compteTresorerieRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> resolver.resoudre(99L, ModePaiement.ESPECES))
                .isInstanceOf(CompteTresorerieNotFoundException.class);
    }

    @Test
    @DisplayName("Sans compte fourni, un paiement en espèces vise la caisse par défaut")
    void defaut_especes() {
        when(compteTresorerieRepository.findParDefautByType(TypeCompteTresorerie.CAISSE))
                .thenReturn(Optional.of(CAISSE));

        assertThat(resolver.resoudre(null, ModePaiement.ESPECES)).isEqualTo(1L);
    }

    @Test
    @DisplayName("Sans compte fourni, un paiement mobile money vise le portefeuille par défaut")
    void defaut_mobile_money() {
        when(compteTresorerieRepository.findParDefautByType(TypeCompteTresorerie.MOBILE_MONEY))
                .thenReturn(Optional.of(WAVE));

        assertThat(resolver.resoudre(null, ModePaiement.MOBILE_MONEY)).isEqualTo(2L);
    }

    @Test
    @DisplayName("Aucun compte par défaut configuré : l'opération reste non rattachée")
    void aucun_compte_par_defaut() {
        when(compteTresorerieRepository.findParDefautByType(any())).thenReturn(Optional.empty());

        assertThat(resolver.resoudre(null, ModePaiement.ESPECES)).isNull();
    }

    @Test
    @DisplayName("Sans mode de paiement, aucune résolution n'est tentée")
    void sans_mode_paiement() {
        assertThat(resolver.resoudre(null, null)).isNull();

        verify(compteTresorerieRepository, never()).findParDefautByType(any());
    }
}
