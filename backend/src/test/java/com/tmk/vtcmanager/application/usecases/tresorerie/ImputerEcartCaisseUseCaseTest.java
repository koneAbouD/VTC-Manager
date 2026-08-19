package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Imputation d'un écart de caisse : la caisse a déjà été réalignée au comptage,
 * ces écritures ne doivent plus jamais la mouvementer.
 */
class ImputerEcartCaisseUseCaseTest {

    private static final Long COMPTE_CAISSE = 7L;
    private static final LocalDate JOUR_DU_COMPTAGE = LocalDate.of(2026, 7, 31);

    private ClotureCaisseRepository clotureCaisseRepository;
    private OperationFinanciereRepository operationRepository;
    private ImputerEcartCaisseUseCase useCase;
    private long prochainId = 100L;

    @BeforeEach
    void setUp() {
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        operationRepository = mock(OperationFinanciereRepository.class);
        CategorieOperationRepository categorieRepository = mock(CategorieOperationRepository.class);
        PeriodeClotureeGuard periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        SequenceReferenceService sequenceReferenceService = mock(SequenceReferenceService.class);
        AuteurCourant auteurCourant = mock(AuteurCourant.class);

        when(categorieRepository.findByCode(anyString())).thenReturn(Optional.empty());
        when(sequenceReferenceService.suivante(any(), any())).thenReturn("CLO-2026-000001");
        when(auteurCourant.nom()).thenReturn("gerant");
        // Chaque écriture ressort de la base avec un identifiant : c'est lui que
        // le relevé retient, faute de quoi l'imputation ne pourrait plus être
        // défaite.
        when(operationRepository.save(any())).thenAnswer(i -> {
            OperationFinanciere ecriture = i.getArgument(0);
            ecriture.setId(prochainId++);
            return ecriture;
        });
        when(clotureCaisseRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        useCase = new ImputerEcartCaisseUseCase(clotureCaisseRepository, operationRepository,
                categorieRepository, periodeClotureeGuard, sequenceReferenceService, auteurCourant);
    }

    private void ecartEnAttente(long ecart) {
        when(clotureCaisseRepository.findById(1L)).thenReturn(Optional.of(ClotureCaisse.builder()
                .id(1L)
                .compteId(COMPTE_CAISSE)
                .dateCloture(JOUR_DU_COMPTAGE)
                .ecart(BigDecimal.valueOf(ecart))
                .responsable("caissier")
                .imputationStatut(StatutImputationEcart.EN_ATTENTE)
                .build()));
    }

    private List<OperationFinanciere> ecrituresGenerees(int nombre) {
        ArgumentCaptor<OperationFinanciere> captor = ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationRepository, times(nombre)).save(captor.capture());
        return captor.getAllValues();
    }

    @Test
    @DisplayName("Manquant recouvré : aucune écriture ne remet d'argent en caisse")
    void recouvree_ne_touche_pas_la_tresorerie() {
        ecartEnAttente(-50_000);

        useCase.executer(1L, StatutImputationEcart.RECOUVREE, "avance au caissier");

        List<OperationFinanciere> ecritures = ecrituresGenerees(1);
        assertThat(ecritures).allSatisfy(o ->
                assertThat(o.getCompteTresorerieId()).isNull());
    }

    @Test
    @DisplayName("Manquant supporté par l'entreprise : la charge est constatée, la caisse intacte")
    void perte_constate_la_charge_sans_toucher_la_tresorerie() {
        ecartEnAttente(-50_000);

        useCase.executer(1L, StatutImputationEcart.PERTE, "manquant non élucidé");

        List<OperationFinanciere> ecritures = ecrituresGenerees(2);
        assertThat(ecritures).allSatisfy(o ->
                assertThat(o.getCompteTresorerieId()).isNull());
        // Solde du compte d'attente au crédit, puis charge au débit.
        assertThat(ecritures.get(0).getTypeOperation()).isEqualTo(TypeOperation.REVENU);
        assertThat(ecritures.get(1).getTypeOperation()).isEqualTo(TypeOperation.DEPENSE);
        assertThat(ecritures.get(1).getMontant()).isEqualByComparingTo("50000");
    }

    @Test
    @DisplayName("Excédent supporté : le produit est constaté, la caisse intacte")
    void excedent_constate_le_produit_sans_toucher_la_tresorerie() {
        ecartEnAttente(30_000);

        useCase.executer(1L, StatutImputationEcart.PERTE, "excédent non élucidé");

        List<OperationFinanciere> ecritures = ecrituresGenerees(2);
        assertThat(ecritures).allSatisfy(o ->
                assertThat(o.getCompteTresorerieId()).isNull());
        assertThat(ecritures.get(0).getTypeOperation()).isEqualTo(TypeOperation.DEPENSE);
        assertThat(ecritures.get(1).getTypeOperation()).isEqualTo(TypeOperation.REVENU);
    }

    @Test
    @DisplayName("Les écritures d'imputation portent la date du comptage, pas celle de la décision")
    void ecritures_datees_du_comptage() {
        ecartEnAttente(-50_000);

        useCase.executer(1L, StatutImputationEcart.PERTE, "manquant non élucidé");

        // Le fait générateur est la journée comptée : c'est le mois de ce
        // comptage qui doit supporter l'écart, même si la décision tombe après.
        assertThat(ecrituresGenerees(2)).allSatisfy(o ->
                assertThat(o.getDateOperation()).isEqualTo(JOUR_DU_COMPTAGE));
    }

    @Test
    @DisplayName("Les deux écritures produites restent rattachées au relevé")
    void ecritures_rattachees_au_releve() {
        ecartEnAttente(-50_000);

        ClotureCaisse resultat = useCase.executer(1L, StatutImputationEcart.PERTE, "manquant");

        // Sans ce rattachement, revenir sur l'imputation serait impossible :
        // l'écriture qui solde le compte d'attente n'était retrouvable nulle
        // part, et le retrait du relevé restait bloqué pour toujours.
        assertThat(resultat.getOperationSoldeAttenteId()).isEqualTo(100L);
        assertThat(resultat.getOperationImputationId()).isEqualTo(101L);
    }

    @Test
    @DisplayName("Recouvrement : seule l'écriture de solde d'attente est rattachée")
    void recouvree_sans_ecriture_de_resultat() {
        ecartEnAttente(-50_000);

        ClotureCaisse resultat = useCase.executer(1L, StatutImputationEcart.RECOUVREE, "avance");

        // Le remboursement ne passe pas par le résultat : il n'y a qu'une
        // écriture, et rien à rattacher du côté de la charge.
        assertThat(resultat.getOperationSoldeAttenteId()).isEqualTo(100L);
        assertThat(resultat.getOperationImputationId()).isNull();
    }

    @Test
    @DisplayName("L'imputation trace la décision, son motif et son auteur")
    void imputation_tracee() {
        ecartEnAttente(-50_000);

        ClotureCaisse resultat = useCase.executer(1L, StatutImputationEcart.RECOUVREE, "avance");

        assertThat(resultat.getImputationStatut()).isEqualTo(StatutImputationEcart.RECOUVREE);
        assertThat(resultat.getImputationMotif()).isEqualTo("avance");
        assertThat(resultat.getImputeePar()).isEqualTo("gerant");
        assertThat(resultat.getImputeeLe()).isNotNull();
    }
}
