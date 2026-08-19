package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.ClotureCaisseDejaEffectueeException;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.exception.MotifEcartObligatoireException;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
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
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Comptage d'une caisse. L'écart entre le solde théorique et le comptage
 * physique est un fait : on l'enregistre en compte d'attente pour réaligner la
 * trésorerie, sans toucher au résultat tant que sa cause n'est pas tranchée.
 *
 * <p>La chronologie des comptages est protégée : pas de comptage futur, pas de
 * comptage rétroactif derrière un comptage plus récent, pas de comptage dans un
 * mois clos.</p>
 */
class CloturerCaisseUseCaseTest {

    private static final Long COMPTE = 1L;
    private static final LocalDate HIER = LocalDate.now().minusDays(1);

    private CompteTresorerieRepository compteTresorerieRepository;
    private ClotureCaisseRepository clotureCaisseRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private CategorieOperationRepository categorieOperationRepository;
    private SequenceReferenceService sequenceReferenceService;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private AuteurCourant auteurCourant;
    private CloturerCaisseUseCase useCase;

    @BeforeEach
    void setUp() {
        compteTresorerieRepository = mock(CompteTresorerieRepository.class);
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        categorieOperationRepository = mock(CategorieOperationRepository.class);
        sequenceReferenceService = mock(SequenceReferenceService.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        auteurCourant = mock(AuteurCourant.class);

        compteAvecSolde(TypeCompteTresorerie.CAISSE, 300_000);
        when(clotureCaisseRepository.existsByCompteIdAndDateCloture(anyLong(), any())).thenReturn(false);
        when(clotureCaisseRepository.findDerniereDateCloture(anyLong())).thenReturn(Optional.empty());
        when(clotureCaisseRepository.save(any())).thenAnswer(inv -> {
            ClotureCaisse c = inv.getArgument(0);
            c.setId(800L);
            return c;
        });
        when(operationFinanciereRepository.save(any())).thenAnswer(inv -> {
            OperationFinanciere op = inv.getArgument(0);
            op.setId(600L);
            return op;
        });
        when(categorieOperationRepository.findByCode(any()))
                .thenAnswer(inv -> Optional.of(CategorieOperation.builder()
                        .id(9L).code(inv.getArgument(0)).build()));
        when(sequenceReferenceService.suivante(any(), any())).thenReturn("CLO-2026-000003");
        when(auteurCourant.nom()).thenReturn("system");

        useCase = new CloturerCaisseUseCase(compteTresorerieRepository, clotureCaisseRepository,
                operationFinanciereRepository, categorieOperationRepository,
                sequenceReferenceService, periodeClotureeGuard, auteurCourant);
    }

    private void compteAvecSolde(TypeCompteTresorerie type, int solde) {
        when(compteTresorerieRepository.findAvecSoldeALaDate(anyLong(), any()))
                .thenReturn(Optional.of(CompteAvecSolde.builder()
                        .compte(CompteTresorerie.builder()
                                .id(COMPTE).libelle("Caisse espèces").type(type).build())
                        .solde(BigDecimal.valueOf(solde))
                        .build()));
    }

    private OperationFinanciere ajustementEnregistre() {
        ArgumentCaptor<OperationFinanciere> capture =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository).save(capture.capture());
        return capture.getValue();
    }

    // ── Comptage conforme ───────────────────────────────────────────────────

    @Test
    @DisplayName("Un comptage conforme ne crée aucune écriture d'ajustement")
    void comptage_conforme() {
        ClotureCaisse cloture = useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(300_000), null, "Aya");

        assertThat(cloture.getId()).isEqualTo(800L);
        assertThat(cloture.getEcart()).isEqualByComparingTo("0");
        assertThat(cloture.getOperationId()).isNull();
        // Sans écart, il n'y a rien à imputer.
        assertThat(cloture.getImputationStatut()).isNull();
        verify(operationFinanciereRepository, never()).save(any());
    }

    @Test
    @DisplayName("Le comptage archive le solde théorique et le solde compté")
    void soldes_archives() {
        ClotureCaisse cloture = useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(296_000), "billet manquant", "Aya");

        assertThat(cloture.getSoldeTheorique()).isEqualByComparingTo("300000");
        assertThat(cloture.getSoldeCompte()).isEqualByComparingTo("296000");
        assertThat(cloture.getDateCloture()).isEqualTo(HIER);
        assertThat(cloture.getResponsable()).isEqualTo("Aya");
    }

    @Test
    @DisplayName("Sans responsable saisi, l'auteur courant est enregistré")
    void responsable_par_defaut() {
        when(auteurCourant.nom()).thenReturn("kouassi");

        ClotureCaisse cloture = useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(300_000), null, "  ");

        assertThat(cloture.getResponsable()).isEqualTo("kouassi");
    }

    @Test
    @DisplayName("Sans date, le comptage porte sur aujourd'hui")
    void date_par_defaut() {
        ClotureCaisse cloture = useCase.executer(
                COMPTE, null, BigDecimal.valueOf(300_000), null, "Aya");

        assertThat(cloture.getDateCloture()).isEqualTo(LocalDate.now());
    }

    // ── Écarts ──────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Un manquant crée une dépense d'attente du montant de l'écart")
    void manquant() {
        ClotureCaisse cloture = useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(296_000), "billet manquant", "Aya");

        assertThat(cloture.getEcart()).isEqualByComparingTo("-4000");
        assertThat(cloture.getImputationStatut()).isEqualTo(StatutImputationEcart.EN_ATTENTE);
        assertThat(cloture.getOperationId()).isEqualTo(600L);

        OperationFinanciere ajustement = ajustementEnregistre();
        assertThat(ajustement.getTypeOperation()).isEqualTo(TypeOperation.DEPENSE);
        assertThat(ajustement.getStatut()).isEqualTo(StatutOperation.PAYE);
        // Le montant de l'écriture est toujours positif : c'est le sens qui porte le signe.
        assertThat(ajustement.getMontant()).isEqualByComparingTo("4000");
        assertThat(ajustement.getCategorie().getCode()).isEqualTo("ECART_CAISSE_ATTENTE_MANQUANT");
        assertThat(ajustement.getCommentaire()).isEqualTo("Clôture de caisse — billet manquant");
        assertThat(ajustement.getReference()).isEqualTo("CLO-2026-000003");
        assertThat(ajustement.getDateOperation()).isEqualTo(HIER);
    }

    @Test
    @DisplayName("Un excédent crée un revenu d'attente")
    void excedent() {
        ClotureCaisse cloture = useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(305_000), "versement non saisi", "Aya");

        assertThat(cloture.getEcart()).isEqualByComparingTo("5000");

        OperationFinanciere ajustement = ajustementEnregistre();
        assertThat(ajustement.getTypeOperation()).isEqualTo(TypeOperation.REVENU);
        assertThat(ajustement.getStatut()).isEqualTo(StatutOperation.ENCAISSE);
        assertThat(ajustement.getMontant()).isEqualByComparingTo("5000");
        assertThat(ajustement.getCategorie().getCode()).isEqualTo("ECART_CAISSE_ATTENTE_EXCEDENT");
    }

    @Test
    @DisplayName("Un écart sans motif est refusé, et le refus dit sur quels nombres il porte")
    void motif_obligatoire_si_ecart() {
        assertThatThrownBy(() -> useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(296_000), "  ", "Aya"))
                .isInstanceOf(MotifEcartObligatoireException.class)
                // Sans ces nombres, l'écran qui affichait un autre solde
                // théorique laisse l'utilisateur devant une exigence qu'il ne
                // peut pas satisfaire : le champ motif ne s'ouvre que lorsque
                // l'écran voit lui-même un écart.
                .satisfies(e -> {
                    MotifEcartObligatoireException ex = (MotifEcartObligatoireException) e;
                    assertThat(ex.getSoldeTheorique()).isEqualByComparingTo("300000");
                    assertThat(ex.getSoldeCompte()).isEqualByComparingTo("296000");
                    assertThat(ex.getEcart()).isEqualByComparingTo("-4000");
                });
        verify(clotureCaisseRepository, never()).save(any());
    }

    @Test
    @DisplayName("L'ajustement d'un portefeuille mobile money porte ce mode de paiement")
    void ajustement_mobile_money() {
        compteAvecSolde(TypeCompteTresorerie.MOBILE_MONEY, 300_000);

        useCase.executer(COMPTE, HIER, BigDecimal.valueOf(296_000), "frais non saisis", "Aya");

        assertThat(ajustementEnregistre().getModePaiement()).isEqualTo(ModePaiement.MOBILE_MONEY);
    }

    @Test
    @DisplayName("L'ajustement d'une caisse porte le mode espèces")
    void ajustement_especes() {
        useCase.executer(COMPTE, HIER, BigDecimal.valueOf(296_000), "billet manquant", "Aya");

        assertThat(ajustementEnregistre().getModePaiement()).isEqualTo(ModePaiement.ESPECES);
        assertThat(ajustementEnregistre().getCompteTresorerieId()).isEqualTo(COMPTE);
    }

    // ── Chronologie et verrous ──────────────────────────────────────────────

    @Test
    @DisplayName("Une caisse ne se compte pas à l'avance")
    void date_future_refusee() {
        assertThatThrownBy(() -> useCase.executer(
                COMPTE, LocalDate.now().plusDays(1), BigDecimal.valueOf(300_000), null, "Aya"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("future");
    }

    @Test
    @DisplayName("Un comptage dans une période close est refusé")
    void periode_close() {
        doThrow(new PeriodeClotureeException(HIER)).when(periodeClotureeGuard).verifier(HIER);

        assertThatThrownBy(() -> useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(300_000), null, "Aya"))
                .isInstanceOf(PeriodeClotureeException.class);
    }

    @Test
    @DisplayName("Une journée déjà comptée ne se recompte pas")
    void jour_deja_compte() {
        when(clotureCaisseRepository.existsByCompteIdAndDateCloture(COMPTE, HIER)).thenReturn(true);

        assertThatThrownBy(() -> useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(300_000), null, "Aya"))
                .isInstanceOf(ClotureCaisseDejaEffectueeException.class);
    }

    @Test
    @DisplayName("On ne compte pas une journée antérieure au dernier comptage")
    void comptage_retroactif_refuse() {
        when(clotureCaisseRepository.findDerniereDateCloture(COMPTE))
                .thenReturn(Optional.of(LocalDate.now()));

        assertThatThrownBy(() -> useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(300_000), null, "Aya"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("on ne recompte pas");
    }

    @Test
    @DisplayName("Un compte inexistant est refusé")
    void compte_introuvable() {
        when(compteTresorerieRepository.findAvecSoldeALaDate(anyLong(), any()))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.executer(
                COMPTE, HIER, BigDecimal.valueOf(300_000), null, "Aya"))
                .isInstanceOf(CompteTresorerieNotFoundException.class);
    }

    @Test
    @DisplayName("Le solde théorique est celui arrêté à la date du comptage")
    void solde_a_la_date_du_comptage() {
        useCase.executer(COMPTE, HIER, BigDecimal.valueOf(300_000), null, "Aya");

        // Compter la caisse d'hier avec le solde d'aujourd'hui inventerait un écart.
        verify(compteTresorerieRepository).findAvecSoldeALaDate(COMPTE, HIER);
    }
}
