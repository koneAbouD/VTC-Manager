package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.LigneRecetteDejaSoldeeException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Fin de vie d'une ligne de recette : annulation et confirmation manuelle du
 * versement, plus le recalcul du statut à partir des encaissements. Une ligne
 * qui a reçu de l'argent ne s'annule pas — il faut d'abord contre-passer les
 * encaissements, sinon la trésorerie et les créances divergent.
 */
class LigneRecetteCycleDeVieTest {

    private static final Long LIGNE_ID = 77L;

    private LigneRecetteRepository ligneRecetteRepository;
    private AnnulerLigneRecetteUseCase annulerUseCase;
    private ConfirmerVersementUseCase confirmerUseCase;

    @BeforeEach
    void setUp() {
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        when(ligneRecetteRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        annulerUseCase = new AnnulerLigneRecetteUseCase(ligneRecetteRepository);
        confirmerUseCase = new ConfirmerVersementUseCase(ligneRecetteRepository);
    }

    private LigneRecette ligne(StatutLigneRecette statut, int encaisse) {
        return LigneRecette.builder()
                .id(LIGNE_ID).vehiculeId(5L).chauffeurId(1L).dateRecette(LocalDate.of(2026, 4, 6))
                .montantAttendu(BigDecimal.valueOf(15_000))
                .montantEncaisse(BigDecimal.valueOf(encaisse))
                .statut(statut).encaissements(new ArrayList<>())
                .build();
    }

    private void enBase(LigneRecette ligne) {
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne));
    }

    @Nested
    @DisplayName("Annulation d'une ligne")
    class Annulation {

        @Test
        @DisplayName("Une ligne en attente s'annule avec son motif horodaté")
        void annulation_nominale() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE, 0));

            LigneRecette annulee = annulerUseCase.executer(LIGNE_ID, "  véhicule accidenté  ");

            assertThat(annulee.getStatut()).isEqualTo(StatutLigneRecette.ANNULEE);
            assertThat(annulee.getMotifAnnulation()).isEqualTo("véhicule accidenté");
            assertThat(annulee.getAnnuleLe()).isNotNull();
        }

        @Test
        @DisplayName("Annuler une ligne déjà annulée ne change rien")
        void annulation_idempotente() {
            LigneRecette dejaAnnulee = ligne(StatutLigneRecette.ANNULEE, 0);
            dejaAnnulee.setMotifAnnulation("premier motif");
            enBase(dejaAnnulee);

            LigneRecette resultat = annulerUseCase.executer(LIGNE_ID, "second motif");

            assertThat(resultat.getMotifAnnulation()).isEqualTo("premier motif");
            verify(ligneRecetteRepository, never()).save(any());
        }

        @ParameterizedTest(name = "motif « {0} » refusé")
        @ValueSource(strings = {"", "   "})
        @DisplayName("Un motif vide est refusé")
        void motif_obligatoire(String motif) {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE, 0));

            assertThatThrownBy(() -> annulerUseCase.executer(LIGNE_ID, motif))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("motif");
        }

        @Test
        @DisplayName("Un motif nul est refusé")
        void motif_nul() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE, 0));

            assertThatThrownBy(() -> annulerUseCase.executer(LIGNE_ID, null))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("Une ligne ayant reçu un versement ne s'annule pas directement")
        void ligne_avec_versement() {
            enBase(ligne(StatutLigneRecette.PARTIELLEMENT_ENCAISSE, 5_000));

            assertThatThrownBy(() -> annulerUseCase.executer(LIGNE_ID, "erreur"))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("Annulez d'abord les encaissements");
            verify(ligneRecetteRepository, never()).save(any());
        }

        @Test
        @DisplayName("Une ligne portant un encaissement, même à zéro, ne s'annule pas")
        void ligne_avec_encaissement_attache() {
            LigneRecette avecEncaissement = ligne(StatutLigneRecette.EN_ATTENTE, 0);
            avecEncaissement.setEncaissements(new ArrayList<>(List.of(
                    Encaissement.builder().id(1L).montant(BigDecimal.ZERO).build())));
            enBase(avecEncaissement);

            assertThatThrownBy(() -> annulerUseCase.executer(LIGNE_ID, "erreur"))
                    .isInstanceOf(IllegalStateException.class);
        }

        @Test
        @DisplayName("Un encaissement extourné ne retient plus l'annulation de la ligne")
        void ligne_avec_encaissement_extourne() {
            // Le versement a été contre-passé : l'argent a été rendu, la ligne
            // n'a plus rien encaissé et redevient annulable. Compter l'écriture
            // restée au journal la bloquerait à perpétuité.
            LigneRecette avecExtourne = ligne(StatutLigneRecette.EN_ATTENTE, 0);
            avecExtourne.setEncaissements(new ArrayList<>(List.of(
                    Encaissement.builder()
                            .id(1L)
                            .montant(BigDecimal.valueOf(5_000))
                            .annuleLe(LocalDateTime.of(2026, 8, 18, 9, 0))
                            .build())));
            enBase(avecExtourne);

            LigneRecette annulee = annulerUseCase.executer(LIGNE_ID, "erreur de génération");

            assertThat(annulee.getStatut()).isEqualTo(StatutLigneRecette.ANNULEE);
        }

        @Test
        @DisplayName("Une ligne inexistante est refusée")
        void ligne_introuvable() {
            when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> annulerUseCase.executer(LIGNE_ID, "erreur"))
                    .isInstanceOf(LigneRecetteNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Confirmation manuelle du versement")
    class Confirmation {

        @Test
        @DisplayName("Une ligne en attente passe en encaissé")
        void confirmation_nominale() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE, 0));

            assertThat(confirmerUseCase.executer(LIGNE_ID).getStatut())
                    .isEqualTo(StatutLigneRecette.ENCAISSE);
        }

        @Test
        @DisplayName("Une ligne partiellement encaissée peut être soldée à la main")
        void confirmation_apres_versement_partiel() {
            // Recette réelle : le montant dû n'est connu qu'à la remise, c'est
            // l'exploitant qui déclare la ligne soldée.
            enBase(ligne(StatutLigneRecette.PARTIELLEMENT_ENCAISSE, 12_000));

            assertThat(confirmerUseCase.executer(LIGNE_ID).getStatut())
                    .isEqualTo(StatutLigneRecette.ENCAISSE);
        }

        @Test
        @DisplayName("Une ligne déjà soldée ou annulée est refusée")
        void ligne_inactive() {
            enBase(ligne(StatutLigneRecette.ENCAISSE, 15_000));
            assertThatThrownBy(() -> confirmerUseCase.executer(LIGNE_ID))
                    .isInstanceOf(LigneRecetteDejaSoldeeException.class);

            enBase(ligne(StatutLigneRecette.ANNULEE, 0));
            assertThatThrownBy(() -> confirmerUseCase.executer(LIGNE_ID))
                    .isInstanceOf(LigneRecetteDejaSoldeeException.class);
        }

        @Test
        @DisplayName("Une ligne inexistante est refusée")
        void ligne_introuvable() {
            when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> confirmerUseCase.executer(LIGNE_ID))
                    .isInstanceOf(LigneRecetteNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Recalcul du statut depuis les encaissements")
    class Recalcul {

        private LigneRecette avecEncaissements(BigDecimal attendu, int... montants) {
            List<Encaissement> encaissements = new ArrayList<>();
            for (int montant : montants) {
                encaissements.add(Encaissement.builder()
                        .montant(BigDecimal.valueOf(montant)).build());
            }
            LigneRecette ligne = ligne(StatutLigneRecette.EN_ATTENTE, 0);
            ligne.setMontantAttendu(attendu);
            ligne.setEncaissements(encaissements);
            return ligne;
        }

        @Test
        @DisplayName("La somme des encaissements donne le montant encaissé")
        void somme_des_encaissements() {
            LigneRecette ligne = avecEncaissements(BigDecimal.valueOf(15_000), 5_000, 4_000);

            ligne.recalculerStatutEtMontant();

            assertThat(ligne.getMontantEncaisse()).isEqualByComparingTo("9000");
            assertThat(ligne.getStatut()).isEqualTo(StatutLigneRecette.PARTIELLEMENT_ENCAISSE);
        }

        @Test
        @DisplayName("Atteindre le montant attendu solde la ligne")
        void montant_atteint() {
            LigneRecette ligne = avecEncaissements(BigDecimal.valueOf(15_000), 15_000);

            ligne.recalculerStatutEtMontant();

            assertThat(ligne.getStatut()).isEqualTo(StatutLigneRecette.ENCAISSE);
        }

        @Test
        @DisplayName("Un dépassement solde aussi la ligne")
        void montant_depasse() {
            LigneRecette ligne = avecEncaissements(BigDecimal.valueOf(15_000), 20_000);

            ligne.recalculerStatutEtMontant();

            assertThat(ligne.getStatut()).isEqualTo(StatutLigneRecette.ENCAISSE);
        }

        @Test
        @DisplayName("Sans encaissement, la ligne retourne en attente")
        void aucun_encaissement() {
            LigneRecette ligne = avecEncaissements(BigDecimal.valueOf(15_000));

            ligne.recalculerStatutEtMontant();

            assertThat(ligne.getMontantEncaisse()).isEqualByComparingTo("0");
            assertThat(ligne.getStatut()).isEqualTo(StatutLigneRecette.EN_ATTENTE);
        }

        @Test
        @DisplayName("En recette réelle, un versement ne solde jamais automatiquement la ligne")
        void recette_reelle_jamais_soldee() {
            LigneRecette ligne = avecEncaissements(null, 50_000);

            ligne.recalculerStatutEtMontant();

            // Seul « Confirmer versement » peut clore une recette réelle.
            assertThat(ligne.getStatut()).isEqualTo(StatutLigneRecette.PARTIELLEMENT_ENCAISSE);
        }
    }
}
