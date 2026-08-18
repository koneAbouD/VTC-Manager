package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementCotisationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementPenaliteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementCotisationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.EncaissementPenaliteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneCotisationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneRecetteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LignePenaliteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OperationFinanciereJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.EncaissementCotisationPersistenceMapper;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.EncaissementPersistenceMapper;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.LignePenalitePersistenceMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Enregistrer un encaissement déjà connu doit le <b>corriger</b>, pas en créer
 * un second.
 *
 * <p>Les dépôts reconstruisaient l'entité à chaque appel : privée de son
 * identifiant, elle repartait en base comme une nouvelle ligne, et son
 * marquage d'annulation se perdait en chemin. Annuler un encaissement de
 * 21 000 F en insérait donc un deuxième, actif : la ligne de recette passait à
 * 42 000 F encaissés au lieu de retomber à zéro, et la créance restait soldée
 * alors que le versement venait d'être annulé.
 */
class EncaissementsAnnulationPersistenceTest {

    private static final Long ENCAISSEMENT_ID = 283L;
    private static final LocalDateTime ANNULE_LE = LocalDateTime.of(2026, 8, 18, 10, 30);

    @Nested
    @DisplayName("Recette")
    class Recette {

        private final EncaissementJpaRepository jpaRepository = mock(EncaissementJpaRepository.class);
        private final LigneRecetteJpaRepository ligneRepository = mock(LigneRecetteJpaRepository.class);
        private final OperationFinanciereJpaRepository operationRepository =
                mock(OperationFinanciereJpaRepository.class);
        private final EncaissementPersistenceMapper mapper = mock(EncaissementPersistenceMapper.class);

        private final EncaissementRepositoryAdapter adapter = new EncaissementRepositoryAdapter(
                jpaRepository, ligneRepository, operationRepository, mapper);

        @Test
        @DisplayName("Un encaissement annulé est mis à jour, avec son marquage")
        void encaissement_existant_mis_a_jour() {
            EncaissementEntity existante = new EncaissementEntity();
            existante.setId(ENCAISSEMENT_ID);
            existante.setMontant(BigDecimal.valueOf(21_000));
            when(jpaRepository.findById(ENCAISSEMENT_ID)).thenReturn(Optional.of(existante));
            when(jpaRepository.save(any())).thenAnswer(i -> i.getArgument(0));

            adapter.save(Encaissement.builder()
                    .id(ENCAISSEMENT_ID)
                    .ligneRecetteId(316L)
                    .montant(BigDecimal.valueOf(21_000))
                    .annuleLe(ANNULE_LE)
                    .annulePar("gerant")
                    .motifAnnulation("erreur de saisie")
                    .build());

            ArgumentCaptor<EncaissementEntity> capture =
                    ArgumentCaptor.forClass(EncaissementEntity.class);
            verify(jpaRepository).save(capture.capture());
            EncaissementEntity sauvee = capture.getValue();

            assertThat(sauvee.getId()).isEqualTo(ENCAISSEMENT_ID);
            assertThat(sauvee.getAnnuleLe()).isEqualTo(ANNULE_LE);
            assertThat(sauvee.getAnnulePar()).isEqualTo("gerant");
            assertThat(sauvee.getMotifAnnulation()).isEqualTo("erreur de saisie");
        }

        @Test
        @DisplayName("Un encaissement neuf est bien créé (id absent)")
        void encaissement_neuf_cree() {
            when(jpaRepository.save(any())).thenAnswer(i -> i.getArgument(0));

            adapter.save(Encaissement.builder()
                    .ligneRecetteId(316L)
                    .montant(BigDecimal.valueOf(5_000))
                    .build());

            ArgumentCaptor<EncaissementEntity> capture =
                    ArgumentCaptor.forClass(EncaissementEntity.class);
            verify(jpaRepository).save(capture.capture());
            assertThat(capture.getValue().getId()).isNull();
            assertThat(capture.getValue().getAnnuleLe()).isNull();
        }
    }

    @Nested
    @DisplayName("Cotisation")
    class Cotisation {

        private final EncaissementCotisationJpaRepository jpaRepository =
                mock(EncaissementCotisationJpaRepository.class);
        private final LigneCotisationJpaRepository ligneRepository = mock(LigneCotisationJpaRepository.class);
        private final OperationFinanciereJpaRepository operationRepository =
                mock(OperationFinanciereJpaRepository.class);
        private final EncaissementCotisationPersistenceMapper mapper =
                mock(EncaissementCotisationPersistenceMapper.class);

        private final EncaissementCotisationRepositoryAdapter adapter =
                new EncaissementCotisationRepositoryAdapter(
                        jpaRepository, ligneRepository, operationRepository, mapper);

        @Test
        @DisplayName("Un encaissement annulé est mis à jour, avec son marquage")
        void encaissement_existant_mis_a_jour() {
            EncaissementCotisationEntity existante = new EncaissementCotisationEntity();
            existante.setId(ENCAISSEMENT_ID);
            when(jpaRepository.findById(ENCAISSEMENT_ID)).thenReturn(Optional.of(existante));
            when(jpaRepository.save(any())).thenAnswer(i -> i.getArgument(0));

            adapter.save(EncaissementCotisation.builder()
                    .id(ENCAISSEMENT_ID)
                    .ligneCotisationId(120L)
                    .montant(BigDecimal.valueOf(3_000))
                    .annuleLe(ANNULE_LE)
                    .annulePar("gerant")
                    .motifAnnulation("erreur de saisie")
                    .build());

            ArgumentCaptor<EncaissementCotisationEntity> capture =
                    ArgumentCaptor.forClass(EncaissementCotisationEntity.class);
            verify(jpaRepository).save(capture.capture());

            assertThat(capture.getValue().getId()).isEqualTo(ENCAISSEMENT_ID);
            assertThat(capture.getValue().getAnnuleLe()).isEqualTo(ANNULE_LE);
        }
    }

    @Nested
    @DisplayName("Pénalité")
    class Penalite {

        private final EncaissementPenaliteJpaRepository jpaRepository =
                mock(EncaissementPenaliteJpaRepository.class);
        private final LignePenaliteJpaRepository ligneRepository = mock(LignePenaliteJpaRepository.class);
        private final OperationFinanciereJpaRepository operationRepository =
                mock(OperationFinanciereJpaRepository.class);
        private final LignePenalitePersistenceMapper mapper = mock(LignePenalitePersistenceMapper.class);

        private final EncaissementPenaliteRepositoryAdapter adapter =
                new EncaissementPenaliteRepositoryAdapter(
                        jpaRepository, ligneRepository, operationRepository, mapper);

        @Test
        @DisplayName("Un encaissement annulé est mis à jour, avec son marquage")
        void encaissement_existant_mis_a_jour() {
            EncaissementPenaliteEntity existante = new EncaissementPenaliteEntity();
            existante.setId(ENCAISSEMENT_ID);
            when(jpaRepository.findById(ENCAISSEMENT_ID)).thenReturn(Optional.of(existante));
            when(jpaRepository.save(any())).thenAnswer(i -> i.getArgument(0));

            adapter.save(EncaissementPenalite.builder()
                    .id(ENCAISSEMENT_ID)
                    .lignePenaliteId(88L)
                    .montant(BigDecimal.valueOf(10_000))
                    .annuleLe(ANNULE_LE)
                    .annulePar("gerant")
                    .motifAnnulation("erreur de saisie")
                    .build());

            ArgumentCaptor<EncaissementPenaliteEntity> capture =
                    ArgumentCaptor.forClass(EncaissementPenaliteEntity.class);
            verify(jpaRepository).save(capture.capture());

            assertThat(capture.getValue().getId()).isEqualTo(ENCAISSEMENT_ID);
            assertThat(capture.getValue().getAnnuleLe()).isEqualTo(ANNULE_LE);
        }
    }
}
