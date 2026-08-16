package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.AucunePenaliteAmendePendingException;
import com.tmk.vtcmanager.application.exception.CaisseClotureeException;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeOuChauffeurSansLigneActiveException;
import com.tmk.vtcmanager.application.exception.VehiculeOuChauffeurSansLigneCotisationActiveException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.PartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CaisseCreditriceGuard;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Saisie manuelle d'une écriture financière. Le use case doit empêcher qu'une
 * saisie libre contourne les modules : un « encaissement de recette » saisi à
 * la main sans ligne de recette active créerait un revenu sans créance en face.
 */
class CreateOperationFinanciereUseCaseTest {

    private static final LocalDate JOUR = LocalDate.of(2026, 4, 10);
    private static final Long VEHICULE = 5L;
    private static final Long CHAUFFEUR = 1L;

    private OperationFinanciereRepository operationRepository;
    private ChauffeurRepository chauffeurRepository;
    private VehiculeRepository vehiculeRepository;
    private LigneRecetteRepository ligneRecetteRepository;
    private LigneCotisationRepository ligneCotisationRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private SousCategorieOperationRepository sousCategorieRepository;
    private PartenaireRepository partenaireRepository;
    private CompteTresorerieResolver compteTresorerieResolver;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private SequenceReferenceService sequenceReferenceService;
    private CaisseClotureeGuard caisseClotureeGuard;
    private CaisseCreditriceGuard caisseCreditriceGuard;
    private CreateOperationFinanciereUseCase useCase;

    @BeforeEach
    void setUp() {
        operationRepository = mock(OperationFinanciereRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        vehiculeRepository = mock(VehiculeRepository.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        sousCategorieRepository = mock(SousCategorieOperationRepository.class);
        partenaireRepository = mock(PartenaireRepository.class);
        compteTresorerieResolver = mock(CompteTresorerieResolver.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        sequenceReferenceService = mock(SequenceReferenceService.class);
        caisseClotureeGuard = mock(CaisseClotureeGuard.class);
        caisseCreditriceGuard = mock(CaisseCreditriceGuard.class);

        when(operationRepository.save(any())).thenAnswer(inv -> {
            OperationFinanciere op = inv.getArgument(0);
            op.setId(600L);
            return op;
        });
        when(chauffeurRepository.findById(CHAUFFEUR))
                .thenReturn(Optional.of(Chauffeur.builder().id(CHAUFFEUR).build()));
        when(vehiculeRepository.findById(VEHICULE))
                .thenReturn(Optional.of(Vehicule.builder().id(VEHICULE).build()));
        when(sousCategorieRepository.findByCategorieId(anyLong())).thenReturn(Optional.empty());
        when(compteTresorerieResolver.resoudre(any(), any())).thenReturn(1L);
        when(sequenceReferenceService.suivante(any())).thenReturn("DEP-2026-000012");

        useCase = new CreateOperationFinanciereUseCase(operationRepository, chauffeurRepository,
                vehiculeRepository, ligneRecetteRepository, ligneCotisationRepository,
                lignePenaliteRepository, sousCategorieRepository, partenaireRepository,
                compteTresorerieResolver, periodeClotureeGuard, sequenceReferenceService,
                caisseClotureeGuard, caisseCreditriceGuard);
    }

    private OperationFinanciere depense() {
        return OperationFinanciere.builder()
                .typeOperation(TypeOperation.DEPENSE)
                .montant(BigDecimal.valueOf(25_000))
                .modePaiement(ModePaiement.ESPECES)
                .dateOperation(JOUR)
                .commentaire("achat de pièces")
                .build();
    }

    private OperationFinanciere avecCategorie(String code, TypeOperation type) {
        return OperationFinanciere.builder()
                .typeOperation(type)
                .categorie(CategorieOperation.builder().id(3L).code(code).build())
                .montant(BigDecimal.valueOf(15_000))
                .modePaiement(ModePaiement.ESPECES)
                .dateOperation(JOUR)
                .vehicule(Vehicule.builder().id(VEHICULE).build())
                .build();
    }

    // ── Cas nominal ─────────────────────────────────────────────────────────

    @Test
    @DisplayName("Une dépense manuelle est enregistrée avec sa référence de journal")
    void depense_enregistree() {
        OperationFinanciere saved = useCase.execute(depense());

        assertThat(saved.getId()).isEqualTo(600L);
        assertThat(saved.getReference()).isEqualTo("DEP-2026-000012");
        verify(sequenceReferenceService).suivante(SequenceReferenceService.Journal.DEPENSE);
    }

    @Test
    @DisplayName("Une recette manuelle est numérotée dans le journal des recettes")
    void recette_journal_distinct() {
        OperationFinanciere revenu = depense();
        revenu.setTypeOperation(TypeOperation.REVENU);

        useCase.execute(revenu);

        verify(sequenceReferenceService).suivante(SequenceReferenceService.Journal.RECETTE);
    }

    @Test
    @DisplayName("Une opération manuelle est directement terminée, sans étape brouillon")
    void statut_par_defaut() {
        assertThat(useCase.execute(depense()).getStatut()).isEqualTo(StatutOperation.PAYE);

        OperationFinanciere revenu = depense();
        revenu.setTypeOperation(TypeOperation.REVENU);
        assertThat(useCase.execute(revenu).getStatut()).isEqualTo(StatutOperation.ENCAISSE);
    }

    @Test
    @DisplayName("Un statut explicitement fourni est respecté")
    void statut_fourni_conserve() {
        // Une dépense saisie comme déjà encaissée (extourne, régularisation)
        // garde le statut voulu par l'appelant.
        OperationFinanciere operation = depense();
        operation.setStatut(StatutOperation.ANNULEE);

        assertThat(useCase.execute(operation).getStatut()).isEqualTo(StatutOperation.ANNULEE);
    }

    @Test
    @DisplayName("Le compte de trésorerie est résolu depuis le mode de paiement")
    void compte_resolu() {
        assertThat(useCase.execute(depense()).getCompteTresorerieId()).isEqualTo(1L);

        verify(compteTresorerieResolver).resoudre(null, ModePaiement.ESPECES);
    }

    @Test
    @DisplayName("La sous-catégorie est résolue côté backend depuis la catégorie")
    void sous_categorie_resolue() {
        SousCategorieOperation sousCategorie = SousCategorieOperation.builder()
                .id(11L).code("ENTRETIEN").build();
        when(sousCategorieRepository.findByCategorieId(3L)).thenReturn(Optional.of(sousCategorie));

        OperationFinanciere operation = depense();
        operation.setCategorie(CategorieOperation.builder().id(3L).code("MAINTENANCE").build());

        // Le formulaire mobile n'envoie que la catégorie : sans cette résolution,
        // le filtre par sous-catégorie des écrans Maintenances / Documents casse.
        assertThat(useCase.execute(operation).getSousCategorie()).isEqualTo(sousCategorie);
    }

    @Test
    @DisplayName("Une sous-catégorie déjà fournie n'est pas écrasée")
    void sous_categorie_fournie_conservee() {
        SousCategorieOperation fournie = SousCategorieOperation.builder().id(22L).build();
        OperationFinanciere operation = depense();
        operation.setCategorie(CategorieOperation.builder().id(3L).code("MAINTENANCE").build());
        operation.setSousCategorie(fournie);

        assertThat(useCase.execute(operation).getSousCategorie()).isEqualTo(fournie);
        verify(sousCategorieRepository, never()).findByCategorieId(anyLong());
    }

    @Test
    @DisplayName("Le montant d'une maintenance détaillée est la somme de ses éléments")
    void montant_calcule_depuis_le_detail() {
        OperationFinanciere operation = depense();
        operation.setMontant(BigDecimal.valueOf(1)); // valeur saisie ignorée
        operation.setDetailMaintenance(DetailMaintenance.builder()
                .elements(new ArrayList<>(List.of(
                        ElementMaintenance.builder().libelle("Plaquettes")
                                .montant(BigDecimal.valueOf(30_000)).build(),
                        ElementMaintenance.builder().libelle("Main d'œuvre")
                                .montant(BigDecimal.valueOf(12_000)).build())))
                .build());

        assertThat(useCase.execute(operation).getMontant()).isEqualByComparingTo("42000");
    }

    @Test
    @DisplayName("Un élément de maintenance sans montant compte pour zéro")
    void element_sans_montant() {
        OperationFinanciere operation = depense();
        operation.setDetailMaintenance(DetailMaintenance.builder()
                .elements(new ArrayList<>(List.of(
                        ElementMaintenance.builder().libelle("Plaquettes")
                                .montant(BigDecimal.valueOf(30_000)).build(),
                        ElementMaintenance.builder().libelle("Offert").montant(null).build())))
                .build());

        assertThat(useCase.execute(operation).getMontant()).isEqualByComparingTo("30000");
    }

    // ── Contrôles de cohérence ──────────────────────────────────────────────

    @Test
    @DisplayName("Une écriture dans une période close est refusée")
    void periode_close() {
        doThrow(new PeriodeClotureeException(JOUR)).when(periodeClotureeGuard).verifier(JOUR);

        assertThatThrownBy(() -> useCase.execute(depense()))
                .isInstanceOf(PeriodeClotureeException.class);
        verify(operationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une écriture sur une caisse déjà comptée est refusée")
    void caisse_comptee() {
        OperationFinanciere operation = depense();
        operation.setCompteTresorerieId(2L);
        doThrow(new CaisseClotureeException(JOUR, JOUR)).when(caisseClotureeGuard).verifier(2L, JOUR);

        assertThatThrownBy(() -> useCase.execute(operation))
                .isInstanceOf(CaisseClotureeException.class);
    }

    @Test
    @DisplayName("Un chauffeur inexistant est refusé")
    void chauffeur_introuvable() {
        when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.empty());
        OperationFinanciere operation = depense();
        operation.setChauffeur(Chauffeur.builder().id(CHAUFFEUR).build());

        assertThatThrownBy(() -> useCase.execute(operation))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    @DisplayName("Un véhicule inexistant est refusé")
    void vehicule_introuvable() {
        when(vehiculeRepository.findById(VEHICULE)).thenReturn(Optional.empty());
        OperationFinanciere operation = depense();
        operation.setVehicule(Vehicule.builder().id(VEHICULE).build());

        assertThatThrownBy(() -> useCase.execute(operation))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    @DisplayName("Un partenaire inexistant est refusé")
    void partenaire_introuvable() {
        when(partenaireRepository.findById(7L)).thenReturn(Optional.empty());
        OperationFinanciere operation = depense();
        operation.setPartenaire(Partenaire.builder().id(7L).build());

        assertThatThrownBy(() -> useCase.execute(operation))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    @DisplayName("Une sortie d'espèces est contrôlée contre le solde de la caisse")
    void depense_controlee_contre_le_solde() {
        useCase.execute(depense());

        verify(caisseCreditriceGuard).verifier(1L, BigDecimal.valueOf(25_000), JOUR);
    }

    @Test
    @DisplayName("Une recette n'est pas contrôlée contre le solde de la caisse")
    void revenu_non_controle() {
        OperationFinanciere revenu = depense();
        revenu.setTypeOperation(TypeOperation.REVENU);

        useCase.execute(revenu);

        verify(caisseCreditriceGuard, never()).verifier(any(), any(), any());
    }

    // ── Gardes anti-contournement des modules ───────────────────────────────

    @Test
    @DisplayName("Un encaissement de recette saisi à la main exige une ligne de recette active")
    void encaissement_recette_sans_ligne() {
        when(ligneRecetteRepository.findActiveByVehiculeIdAndDate(VEHICULE, JOUR))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.execute(
                avecCategorie("ENCAISSEMENT_RECETTES", TypeOperation.REVENU)))
                .isInstanceOf(VehiculeOuChauffeurSansLigneActiveException.class);
    }

    @Test
    @DisplayName("Une ligne de recette active autorise la saisie manuelle")
    void encaissement_recette_avec_ligne() {
        when(ligneRecetteRepository.findActiveByVehiculeIdAndDate(VEHICULE, JOUR))
                .thenReturn(Optional.of(LigneRecette.builder().id(70L).build()));

        assertThatCode(() -> useCase.execute(
                avecCategorie("ENCAISSEMENT_RECETTES", TypeOperation.REVENU)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("À défaut de véhicule, la ligne active est cherchée sur le chauffeur")
    void encaissement_recette_repli_chauffeur() {
        OperationFinanciere operation = avecCategorie("ENCAISSEMENT_RECETTES", TypeOperation.REVENU);
        operation.setVehicule(null);
        operation.setChauffeur(Chauffeur.builder().id(CHAUFFEUR).build());
        when(ligneRecetteRepository.findActiveByChauffeurIdAndDate(CHAUFFEUR, JOUR))
                .thenReturn(Optional.of(LigneRecette.builder().id(70L).build()));

        assertThatCode(() -> useCase.execute(operation)).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Un encaissement de cotisation exige une ligne de cotisation active")
    void encaissement_cotisation_sans_ligne() {
        when(ligneCotisationRepository.findActiveByVehiculeIdAndDate(VEHICULE, JOUR))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.execute(
                avecCategorie("ENCAISSEMENT_COTISATIONS", TypeOperation.REVENU)))
                .isInstanceOf(VehiculeOuChauffeurSansLigneCotisationActiveException.class);
    }

    @Test
    @DisplayName("Une ligne de cotisation active autorise la saisie manuelle")
    void encaissement_cotisation_avec_ligne() {
        when(ligneCotisationRepository.findActiveByVehiculeIdAndDate(VEHICULE, JOUR))
                .thenReturn(Optional.of(LigneCotisation.builder().id(80L).build()));

        assertThatCode(() -> useCase.execute(
                avecCategorie("ENCAISSEMENT_COTISATIONS", TypeOperation.REVENU)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Un encaissement de pénalité exige une amende en attente")
    void encaissement_penalite_sans_amende() {
        when(lignePenaliteRepository.hasAmendePendingByVehiculeOrChauffeur(anyLong(), anyLong()))
                .thenReturn(false);

        assertThatThrownBy(() -> useCase.execute(
                avecCategorie("ENCAISSEMENT_PENALITES", TypeOperation.REVENU)))
                .isInstanceOf(AucunePenaliteAmendePendingException.class);
    }

    @Test
    @DisplayName("Un encaissement de pénalité sans véhicule ni chauffeur est refusé")
    void encaissement_penalite_sans_cible() {
        OperationFinanciere operation = avecCategorie("ENCAISSEMENT_PENALITES", TypeOperation.REVENU);
        operation.setVehicule(null);

        assertThatThrownBy(() -> useCase.execute(operation))
                .isInstanceOf(AucunePenaliteAmendePendingException.class);
        verify(lignePenaliteRepository, never())
                .hasAmendePendingByVehiculeOrChauffeur(anyLong(), anyLong());
    }

    @Test
    @DisplayName("Une amende en attente autorise la saisie manuelle")
    void encaissement_penalite_avec_amende() {
        when(lignePenaliteRepository.hasAmendePendingByVehiculeOrChauffeur(VEHICULE, -1L))
                .thenReturn(true);

        assertThatCode(() -> useCase.execute(
                avecCategorie("ENCAISSEMENT_PENALITES", TypeOperation.REVENU)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Une dépense ordinaire n'est soumise à aucune de ces gardes")
    void depense_sans_garde() {
        useCase.execute(avecCategorie("CARBURANT", TypeOperation.DEPENSE));

        verify(ligneRecetteRepository, never()).findActiveByVehiculeIdAndDate(anyLong(), any());
        verify(ligneCotisationRepository, never()).findActiveByVehiculeIdAndDate(anyLong(), any());
        verify(lignePenaliteRepository, never())
                .hasAmendePendingByVehiculeOrChauffeur(anyLong(), anyLong());
    }
}
