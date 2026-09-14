package com.tmk.vtcmanager.application.usecases.versement;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.versement.PartVersement;
import com.tmk.vtcmanager.application.domain.versement.SaisieVersement;
import com.tmk.vtcmanager.application.domain.versement.VersementEnregistre;
import com.tmk.vtcmanager.application.exception.EncaissementDepasseMontantDuException;
import com.tmk.vtcmanager.application.exception.VersementIncoherentException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.usecases.cotisation.CreateEncaissementCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.recette.CreateEncaissementUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Un billet pour la recette et la cotisation du jour.
 *
 * <p>Ce que ces tests fixent : les deux écritures reçoivent le même
 * identifiant de versement, et lui seul les rassemble ; une recette et une
 * cotisation qui ne sont pas sœurs ne peuvent pas être présentées ensemble ;
 * un refus remonte tel quel sans que rien ne soit rassemblé.
 *
 * <p>L'annulation de la recette quand la cotisation est refusée relève de la
 * transaction — le proxy du use case — et ne se voit pas dans un test unitaire :
 * on vérifie ici que le refus traverse le use case sans être avalé.
 */
@DisplayName("Encaissement d'un versement (recette + cotisation du jour)")
class EncaisserVersementUseCaseTest {

    private static final LocalDate LA_JOURNEE = LocalDate.of(2026, 9, 10);
    private static final LocalDate VERSE_LE = LocalDate.of(2026, 9, 11);
    private static final Long VEHICULE = 7L;
    private static final Long CHAUFFEUR = 3L;
    private static final Long RECETTE_ID = 1L;
    private static final Long COTISATION_ID = 91L;

    private CreateEncaissementUseCase recettes;
    private CreateEncaissementCotisationUseCase cotisations;
    private LigneRecetteRepository ligneRecetteRepository;
    private LigneCotisationRepository ligneCotisationRepository;
    private OperationFinanciereRepository operationRepository;
    private EncaisserVersementUseCase useCase;

    @BeforeEach
    void setUp() {
        recettes = mock(CreateEncaissementUseCase.class);
        cotisations = mock(CreateEncaissementCotisationUseCase.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        operationRepository = mock(OperationFinanciereRepository.class);

        when(ligneRecetteRepository.findById(RECETTE_ID))
                .thenReturn(Optional.of(recette(VEHICULE, CHAUFFEUR, LA_JOURNEE)));
        when(ligneCotisationRepository.findById(COTISATION_ID))
                .thenReturn(Optional.of(cotisation(VEHICULE, CHAUFFEUR, LA_JOURNEE)));
        when(recettes.executer(eq(RECETTE_ID), any(Encaissement.class)))
                .thenReturn(Encaissement.builder().id(11L).operationFinanciereId(501L).build());
        when(cotisations.executer(eq(COTISATION_ID), any(EncaissementCotisation.class)))
                .thenReturn(EncaissementCotisation.builder().id(22L).operationFinanciereId(502L).build());

        useCase = new EncaisserVersementUseCase(recettes, cotisations, ligneRecetteRepository,
                ligneCotisationRepository, operationRepository);
    }

    private static LigneRecette recette(Long vehicule, Long chauffeur, LocalDate jour) {
        return LigneRecette.builder().id(RECETTE_ID)
                .vehiculeId(vehicule).vehiculeImmatriculation(immatriculation(vehicule))
                .chauffeurId(chauffeur).chauffeurNom(nom(chauffeur))
                .dateRecette(jour).build();
    }

    private static LigneCotisation cotisation(Long vehicule, Long chauffeur, LocalDate jour) {
        return LigneCotisation.builder().id(COTISATION_ID)
                .vehiculeId(vehicule).vehiculeImmatriculation(immatriculation(vehicule))
                .chauffeurId(chauffeur).chauffeurNom(nom(chauffeur))
                .dateCotisation(jour).build();
    }

    private static String immatriculation(Long vehicule) {
        return vehicule.equals(VEHICULE) ? "1234 AB 01" : "5678 CD 01";
    }

    private static String nom(Long chauffeur) {
        return chauffeur.equals(CHAUFFEUR) ? "Jean Kouassi" : "Awa Traoré";
    }

    private static PartVersement part(Long ligneId, String montant) {
        return new PartVersement(ligneId, new BigDecimal(montant));
    }

    private static SaisieVersement saisie(PartVersement recette, PartVersement cotisation) {
        return new SaisieVersement(recette, cotisation, ModePaiement.ESPECES, VERSE_LE,
                null, "Versement du matin");
    }

    @Test
    @DisplayName("les deux écritures reçoivent le même versement")
    @SuppressWarnings("unchecked")
    void rassembleLesDeuxEcritures() {
        VersementEnregistre enregistre = useCase.executer(
                saisie(part(RECETTE_ID, "15000"), part(COTISATION_ID, "2000")));

        ArgumentCaptor<List<Long>> ecritures = ArgumentCaptor.forClass(List.class);
        ArgumentCaptor<UUID> versement = ArgumentCaptor.forClass(UUID.class);
        verify(operationRepository).rattacherAuVersement(ecritures.capture(), versement.capture());

        assertThat(ecritures.getValue()).containsExactly(501L, 502L);
        assertThat(versement.getValue()).isNotNull();
        assertThat(enregistre.versementId()).isEqualTo(versement.getValue());
        assertThat(enregistre.encaissementRecetteId()).isEqualTo(11L);
        assertThat(enregistre.encaissementCotisationId()).isEqualTo(22L);
        assertThat(enregistre.operationIds()).containsExactly(501L, 502L);
    }

    @Test
    @DisplayName("chaque créance reçoit sa part, avec le mode, la date et le commentaire du billet")
    void chaquePartAvecLeBillet() {
        useCase.executer(saisie(part(RECETTE_ID, "15000"), part(COTISATION_ID, "2000")));

        ArgumentCaptor<Encaissement> recette = ArgumentCaptor.forClass(Encaissement.class);
        verify(recettes).executer(eq(RECETTE_ID), recette.capture());
        assertThat(recette.getValue().getMontant()).isEqualByComparingTo("15000");
        assertThat(recette.getValue().getModeEncaissement()).isEqualTo(ModePaiement.ESPECES);
        assertThat(recette.getValue().getDateEncaissement()).isEqualTo(VERSE_LE);
        assertThat(recette.getValue().getCommentaire()).isEqualTo("Versement du matin");

        ArgumentCaptor<EncaissementCotisation> cotisation =
                ArgumentCaptor.forClass(EncaissementCotisation.class);
        verify(cotisations).executer(eq(COTISATION_ID), cotisation.capture());
        assertThat(cotisation.getValue().getMontant()).isEqualByComparingTo("2000");
        assertThat(cotisation.getValue().getModeEncaissement()).isEqualTo(ModePaiement.ESPECES);
        assertThat(cotisation.getValue().getDateEncaissement()).isEqualTo(VERSE_LE);
    }

    @Test
    @DisplayName("une seule créance soldée : aucune pièce de caisse à former")
    void uneSeulePart() {
        VersementEnregistre enregistre = useCase.executer(saisie(part(RECETTE_ID, "15000"), null));

        assertThat(enregistre.versementId()).isNull();
        assertThat(enregistre.encaissementRecetteId()).isEqualTo(11L);
        assertThat(enregistre.encaissementCotisationId()).isNull();
        assertThat(enregistre.operationIds()).containsExactly(501L);
        verify(cotisations, never()).executer(anyLong(), any());
        verify(operationRepository, never()).rattacherAuVersement(any(), any());
        // Rien à apparier : les lignes ne sont même pas relues.
        verify(ligneCotisationRepository, never()).findById(anyLong());
    }

    @Test
    @DisplayName("la cotisation seule passe aussi, sans pièce de caisse")
    void cotisationSeule() {
        VersementEnregistre enregistre = useCase.executer(saisie(null, part(COTISATION_ID, "2000")));

        assertThat(enregistre.versementId()).isNull();
        assertThat(enregistre.encaissementCotisationId()).isEqualTo(22L);
        verify(recettes, never()).executer(anyLong(), any());
    }

    @Test
    @DisplayName("sans aucune part, le versement est refusé avant toute écriture")
    void aucunePart() {
        assertThatThrownBy(() -> useCase.executer(saisie(null, null)))
                .isInstanceOf(IllegalArgumentException.class);

        verifyNoInteractions(recettes, cotisations, operationRepository);
    }

    @Test
    @DisplayName("un autre chauffeur : le refus nomme les deux chauffeurs, et rien d'autre")
    void autreChauffeur() {
        when(ligneCotisationRepository.findById(COTISATION_ID))
                .thenReturn(Optional.of(cotisation(VEHICULE, 4L, LA_JOURNEE)));

        assertThatThrownBy(() -> useCase.executer(
                saisie(part(RECETTE_ID, "15000"), part(COTISATION_ID, "2000"))))
                .isInstanceOf(VersementIncoherentException.class)
                .hasMessageContaining("Chauffeur différent : Jean Kouassi pour la recette,"
                        + " Awa Traoré pour la cotisation.")
                .hasMessageNotContaining("Véhicule différent")
                .hasMessageNotContaining("Jour différent")
                .hasMessageEndingWith("Encaissez-les séparément.");

        verifyNoInteractions(recettes, cotisations, operationRepository);
    }

    @Test
    @DisplayName("une autre journée : le refus donne les deux dates")
    void autreJour() {
        when(ligneCotisationRepository.findById(COTISATION_ID))
                .thenReturn(Optional.of(cotisation(VEHICULE, CHAUFFEUR, LA_JOURNEE.minusDays(1))));

        assertThatThrownBy(() -> useCase.executer(
                saisie(part(RECETTE_ID, "15000"), part(COTISATION_ID, "2000"))))
                .isInstanceOf(VersementIncoherentException.class)
                .hasMessageContaining("Jour différent : recette du 10/09/2026, cotisation du 09/09/2026.")
                .hasMessageNotContaining("Chauffeur différent")
                .hasMessageNotContaining("Véhicule différent");

        verifyNoInteractions(recettes, cotisations);
    }

    @Test
    @DisplayName("un autre véhicule : le refus donne les deux immatriculations")
    void autreVehicule() {
        when(ligneCotisationRepository.findById(COTISATION_ID))
                .thenReturn(Optional.of(cotisation(8L, CHAUFFEUR, LA_JOURNEE)));

        assertThatThrownBy(() -> useCase.executer(
                saisie(part(RECETTE_ID, "15000"), part(COTISATION_ID, "2000"))))
                .isInstanceOf(VersementIncoherentException.class)
                .hasMessageContaining("Véhicule différent : 1234 AB 01 pour la recette,"
                        + " 5678 CD 01 pour la cotisation.")
                .hasMessageNotContaining("Chauffeur différent")
                .hasMessageNotContaining("Jour différent");
    }

    @Test
    @DisplayName("plusieurs écarts : chacun est nommé, dans l'ordre véhicule, chauffeur, jour")
    void plusieursEcarts() {
        when(ligneCotisationRepository.findById(COTISATION_ID))
                .thenReturn(Optional.of(cotisation(VEHICULE, 4L, LA_JOURNEE.plusDays(1))));

        assertThatThrownBy(() -> useCase.executer(
                saisie(part(RECETTE_ID, "15000"), part(COTISATION_ID, "2000"))))
                .isInstanceOf(VersementIncoherentException.class)
                .hasMessage("Cette recette et cette cotisation ne peuvent pas être réglées par un"
                        + " seul versement. Chauffeur différent : Jean Kouassi pour la recette,"
                        + " Awa Traoré pour la cotisation. Jour différent : recette du 10/09/2026,"
                        + " cotisation du 11/09/2026. Encaissez-les séparément.");
    }

    @Test
    @DisplayName("cotisation refusée : le refus remonte, et rien n'est rassemblé")
    void cotisationRefusee() {
        when(cotisations.executer(eq(COTISATION_ID), any(EncaissementCotisation.class)))
                .thenThrow(new EncaissementDepasseMontantDuException(new BigDecimal("1000")));

        assertThatThrownBy(() -> useCase.executer(
                saisie(part(RECETTE_ID, "15000"), part(COTISATION_ID, "2000"))))
                .isInstanceOf(EncaissementDepasseMontantDuException.class);

        verify(operationRepository, never()).rattacherAuVersement(any(), any());
    }
}
