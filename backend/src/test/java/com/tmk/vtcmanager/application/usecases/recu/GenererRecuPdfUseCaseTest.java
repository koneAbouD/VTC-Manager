package com.tmk.vtcmanager.application.usecases.recu;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.domain.recu.RecuPaiement;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.versement.ImputationVersement;
import com.tmk.vtcmanager.application.domain.versement.NatureImputation;
import com.tmk.vtcmanager.application.exception.RecuImpossibleException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.document.RecuDocumentRenderer;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.ChauffeursAuProgrammeService;
import com.tmk.vtcmanager.application.services.LectureImputationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
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
 * Reçu PDF : un reçu atteste un argent qui compte encore, reçu d'un seul payeur
 * pour ses créances. Ces tests fixent ce qu'il rassemble et ce qu'il refuse.
 */
@DisplayName("Génération du reçu PDF")
class GenererRecuPdfUseCaseTest {

    private static final LocalDate LA_JOURNEE = LocalDate.of(2026, 9, 10);
    private static final LocalDate VERSE_LE = LocalDate.of(2026, 9, 11);

    private OperationFinanciereRepository operationRepository;
    private LectureImputationService lecture;
    private RecuDocumentRenderer renderer;
    private LigneRecetteRepository recettes;
    private LigneCotisationRepository cotisations;
    private ChauffeursAuProgrammeService planning;
    private CreanceRepository creances;
    private GenererRecuPdfUseCase useCase;

    @BeforeEach
    void setUp() {
        operationRepository = mock(OperationFinanciereRepository.class);
        lecture = mock(LectureImputationService.class);
        renderer = mock(RecuDocumentRenderer.class);
        when(renderer.renderRecuPdf(any())).thenReturn(new byte[]{1, 2, 3});
        recettes = mock(LigneRecetteRepository.class);
        cotisations = mock(LigneCotisationRepository.class);
        when(recettes.findByChauffeurIdAndDateRecette(any(), any())).thenReturn(List.of());
        when(cotisations.findByChauffeurIdAndDateCotisation(any(), any())).thenReturn(List.of());
        planning = mock(ChauffeursAuProgrammeService.class);
        creances = mock(CreanceRepository.class);
        when(creances.getLignesCreance(any())).thenReturn(List.of());
        when(creances.getResteCotisations(any())).thenReturn(BigDecimal.ZERO);
        useCase = new GenererRecuPdfUseCase(operationRepository, lecture, renderer, recettes, cotisations,
                planning, creances);
    }

    private static CategorieOperation categorie(String code) {
        return CategorieOperation.builder().code(code).libelle(code).build();
    }

    private OperationFinanciere ecriture(long id, String code, String montant, long chauffeur) {
        OperationFinanciere op = OperationFinanciere.builder()
                .id(id).reference("ENC-2026-000" + id)
                .categorie(categorie(code))
                .montant(new BigDecimal(montant))
                .modePaiement(ModePaiement.ESPECES)
                .dateOperation(VERSE_LE).dateReference(LA_JOURNEE)
                .statut(StatutOperation.ENCAISSE)
                .chauffeur(Chauffeur.builder().id(chauffeur).prenom("Jean").nom("Kouassi")
                        .telephone("0712345678").build())
                .vehicule(Vehicule.builder().id(7L).immatriculation("1234 AB 01").build())
                .build();
        when(operationRepository.findById(id)).thenReturn(Optional.of(op));
        return op;
    }

    private void lu(OperationFinanciere op, NatureImputation nature, String libelle, long ligneId,
                    String resteDu) {
        when(lecture.lire(op)).thenReturn(new ImputationVersement(op.getId(), op.getReference(), nature,
                libelle, ligneId, op.getDateReference(), op.getMontant(), false,
                resteDu == null ? null : new BigDecimal(resteDu), null));
    }

    private void recetteDuJour(String attendu, String encaisse) {
        when(recettes.findByChauffeurIdAndDateRecette(3L, LA_JOURNEE)).thenReturn(List.of(
                LigneRecette.builder().statut(StatutLigneRecette.PARTIELLEMENT_ENCAISSE)
                        .montantAttendu(attendu == null ? null : new BigDecimal(attendu))
                        .montantEncaisse(new BigDecimal(encaisse)).build()));
    }

    private void cotisationDuJour(String du, String encaisse) {
        when(cotisations.findByChauffeurIdAndDateCotisation(3L, LA_JOURNEE)).thenReturn(List.of(
                LigneCotisation.builder().statut(StatutLigneCotisation.EN_ATTENTE)
                        .montantDu(new BigDecimal(du)).montantEncaisse(new BigDecimal(encaisse)).build()));
    }

    private RecuPaiement recuRendu() {
        ArgumentCaptor<RecuPaiement> recu = ArgumentCaptor.forClass(RecuPaiement.class);
        verify(renderer).renderRecuPdf(recu.capture());
        return recu.getValue();
    }

    @Test
    @DisplayName("un versement : recette et cotisation au même reçu, reste dû additionné")
    void versement() {
        lu(ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3), NatureImputation.RECETTE, "Recette", 1, "5000");
        lu(ecriture(502, "ENCAISSEMENT_COTISATIONS", "2000", 3), NatureImputation.COTISATION,
                "Cotisation carburant", 91, "0");
        recetteDuJour("20000", "15000");
        cotisationDuJour("2000", "2000");

        byte[] pdf = useCase.executer(List.of(502L, 501L));

        assertThat(pdf).containsExactly(1, 2, 3);
        RecuPaiement recu = recuRendu();
        assertThat(recu.entreprise()).isEqualTo("TMK");
        assertThat(recu.chauffeurNom()).isEqualTo("Jean Kouassi");
        assertThat(recu.total()).isEqualByComparingTo("17000");
        assertThat(recu.resteDu()).isEqualByComparingTo("5000");
        assertThat(recu.vehicules()).containsExactly("1234 AB 01");
        assertThat(recu.modesPaiement()).containsExactly(ModePaiement.ESPECES);
        // Dans l'ordre du guichet, quel que soit celui de la demande.
        assertThat(recu.lignes()).extracting(l -> l.libelle())
                .containsExactly("Recette", "Cotisation carburant");
        assertThat(recu.lignes().get(0).journee()).isEqualTo(LA_JOURNEE);
        assertThat(recu.lignes().get(0).payeLe()).isEqualTo(VERSE_LE);
    }

    @Test
    @DisplayName("lire rend le reçu en données, sans produire de PDF")
    void lireSansPdf() {
        lu(ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3), NatureImputation.RECETTE, "Recette", 1, "5000");
        recetteDuJour("20000", "15000");

        RecuPaiement recu = useCase.lire(List.of(501L));

        assertThat(recu.chauffeurNom()).isEqualTo("Jean Kouassi");
        assertThat(recu.total()).isEqualByComparingTo("15000");
        assertThat(recu.resteDu()).isEqualByComparingTo("5000");
        verify(renderer, never()).renderRecuPdf(any());
    }

    @Test
    @DisplayName("lire oppose les mêmes refus que le PDF")
    void lireMemesRefus() {
        assertThatThrownBy(() -> useCase.lire(List.of()))
                .isInstanceOf(RecuImpossibleException.class);
    }

    @Test
    @DisplayName("deux versements partiels d'une même recette : son reste ne compte qu'une fois")
    void memeCreanceUneFois() {
        lu(ecriture(501, "ENCAISSEMENT_RECETTES", "5000", 3), NatureImputation.RECETTE, "Recette", 1, "3000");
        lu(ecriture(503, "ENCAISSEMENT_RECETTES", "7000", 3), NatureImputation.RECETTE, "Recette", 1, "3000");
        recetteDuJour("15000", "12000");

        useCase.executer(List.of(501L, 503L));

        assertThat(recuRendu().resteDu()).isEqualByComparingTo("3000");
    }

    @Test
    @DisplayName("une créance qui ignore son reste rend le solde inconnu")
    void resteInconnu() {
        lu(ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3), NatureImputation.RECETTE, "Recette", 1, null);
        lu(ecriture(502, "ENCAISSEMENT_COTISATIONS", "2000", 3), NatureImputation.COTISATION, "Cotisation", 91, "0");
        recetteDuJour(null, "15000");

        useCase.executer(List.of(501L, 502L));

        assertThat(recuRendu().resteDu()).isNull();
    }

    @Test
    @DisplayName("le reste à payer ne porte que sur la recette et la cotisation du jour")
    void resteDuJour() {
        // Seule la recette est versée : la cotisation du même jour reste due.
        lu(ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3), NatureImputation.RECETTE, "Recette", 1, "0");
        recetteDuJour("15000", "15000");
        cotisationDuJour("2000", "500");

        RecuPaiement recu = useCase.lire(List.of(501L));

        assertThat(recu.resteDu()).isEqualByComparingTo("1500");
        verify(recettes).findByChauffeurIdAndDateRecette(3L, LA_JOURNEE);
        verify(cotisations).findByChauffeurIdAndDateCotisation(3L, LA_JOURNEE);
    }

    @Test
    @DisplayName("le total des créances : recettes, pénalités et cotisations, hors contraventions")
    void totalCreances() {
        lu(ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3), NatureImputation.RECETTE, "Recette", 1, "0");
        recetteDuJour("15000", "15000");
        when(creances.getLignesCreance(3L)).thenReturn(List.of(
                LigneCreance.builder().document(TypeDocumentCreance.RECETTE)
                        .restant(new BigDecimal("10000")).build(),
                LigneCreance.builder().document(TypeDocumentCreance.PENALITE)
                        .restant(new BigDecimal("2000")).build(),
                LigneCreance.builder().document(TypeDocumentCreance.CONTRAVENTION)
                        .restant(new BigDecimal("25000")).build()));
        when(creances.getResteCotisations(3L)).thenReturn(new BigDecimal("3000"));

        RecuPaiement recu = useCase.lire(List.of(501L));

        assertThat(recu.resteDu()).isEqualByComparingTo("0");
        assertThat(recu.detteChauffeur()).isEqualByComparingTo("15000");
        verify(creances).getLignesCreance(3L);
        verify(creances).getResteCotisations(3L);
    }

    @Test
    @DisplayName("sans autre dette, le chauffeur est à jour")
    void chauffeurAJour() {
        lu(ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3), NatureImputation.RECETTE, "Recette", 1, "0");

        assertThat(useCase.lire(List.of(501L)).detteChauffeur()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("en service : au volant s'il est au planning du jour, au repos sinon")
    void auVolantOuAuRepos() {
        OperationFinanciere op = ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3);
        op.getChauffeur().setStatut(ChauffeurStatus.EN_SERVICE);
        lu(op, NatureImputation.RECETTE, "Recette", 1, "0");

        when(planning.estAuProgramme(3L, LocalDate.now())).thenReturn(true);
        assertThat(useCase.lire(List.of(501L)).chauffeurAuVolant()).isTrue();

        when(planning.estAuProgramme(3L, LocalDate.now())).thenReturn(false);
        assertThat(useCase.lire(List.of(501L)).chauffeurAuVolant()).isFalse();
    }

    @Test
    @DisplayName("hors service, le reçu ne dit ni route ni repos")
    void horsService() {
        OperationFinanciere op = ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3);
        op.getChauffeur().setStatut(ChauffeurStatus.EN_CONGE);
        lu(op, NatureImputation.RECETTE, "Recette", 1, "0");

        assertThat(useCase.lire(List.of(501L)).chauffeurAuVolant()).isNull();
        verify(planning, never()).estAuProgramme(any(), any());
    }

    @Test
    @DisplayName("une écriture annulée ne s'atteste pas : le refus la nomme")
    void ecritureAnnulee() {
        OperationFinanciere op = ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3);
        op.setAnnuleLe(LocalDateTime.of(2026, 9, 12, 9, 0));

        assertThatThrownBy(() -> useCase.executer(List.of(501L)))
                .isInstanceOf(RecuImpossibleException.class)
                .hasMessageContaining("ENC-2026-000501 a été annulée");
        verify(renderer, never()).renderRecuPdf(any());
    }

    @Test
    @DisplayName("une dépense ne se quittance pas au chauffeur")
    void pasUnEncaissement() {
        ecriture(601, "VIDANGE", "12000", 3);

        assertThatThrownBy(() -> useCase.executer(List.of(601L)))
                .isInstanceOf(RecuImpossibleException.class)
                .hasMessageContaining("ne règle ni une recette, ni une cotisation, ni une pénalité");
    }

    @Test
    @DisplayName("un reçu n'a qu'un destinataire : deux chauffeurs sont refusés")
    void deuxChauffeurs() {
        lu(ecriture(501, "ENCAISSEMENT_RECETTES", "15000", 3), NatureImputation.RECETTE, "Recette", 1, "0");
        lu(ecriture(504, "ENCAISSEMENT_RECETTES", "12000", 4), NatureImputation.RECETTE, "Recette", 2, "0");

        assertThatThrownBy(() -> useCase.executer(List.of(501L, 504L)))
                .isInstanceOf(RecuImpossibleException.class)
                .hasMessageContaining("pas au nom du même chauffeur");
    }

    @Test
    @DisplayName("sans écriture, rien à attester")
    void aucuneEcriture() {
        assertThatThrownBy(() -> useCase.executer(List.of()))
                .isInstanceOf(RecuImpossibleException.class);
    }

    @Test
    @DisplayName("une écriture inconnue est introuvable")
    void introuvable() {
        when(operationRepository.findById(999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.executer(List.of(999L)))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
