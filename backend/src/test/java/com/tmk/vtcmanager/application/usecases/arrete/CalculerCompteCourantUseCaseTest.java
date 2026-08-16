package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Arrêté de compte : le fonds de cotisation du chauffeur éteint ses créances
 * ouvertes, de la plus ancienne à la plus récente, et ce qui reste lui est
 * restitué. C'est un calcul d'argent rendu à une personne : une erreur
 * d'allocation se paie en espèces.
 *
 * <p>Ce use case n'écrit rien — il ne fait que calculer.</p>
 */
class CalculerCompteCourantUseCaseTest {

    private static final Long CHAUFFEUR = 1L;
    private static final Long VEHICULE = 5L;
    private static final LocalDate DEBUT = LocalDate.of(2026, 3, 1);
    private static final LocalDate FIN = LocalDate.of(2026, 3, 31);

    private LigneCotisationRepository ligneCotisationRepository;
    private CreanceRepository creanceRepository;
    private ChauffeurRepository chauffeurRepository;
    private CalculerCompteCourantUseCase useCase;

    @BeforeEach
    void setUp() {
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        creanceRepository = mock(CreanceRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);

        when(ligneCotisationRepository.findByCriteres(any())).thenReturn(List.of());
        when(creanceRepository.getLignesCreance(anyLong())).thenReturn(List.of());
        when(creanceRepository.getLignesCreanceParVehicule(anyLong())).thenReturn(List.of());
        when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.of(
                Chauffeur.builder().id(CHAUFFEUR).prenom("Aya").nom("Kouassi").build()));

        useCase = new CalculerCompteCourantUseCase(
                ligneCotisationRepository, creanceRepository, chauffeurRepository);
    }

    // ── Fixtures ────────────────────────────────────────────────────────────

    private LigneCotisation cotisation(Long id, int encaisse, StatutLigneCotisation statut) {
        return LigneCotisation.builder()
                .id(id).chauffeurId(CHAUFFEUR).vehiculeId(VEHICULE)
                .dateCotisation(DEBUT.plusDays(3)).nomCotisation("Épargne")
                .montantDu(BigDecimal.valueOf(1_000))
                .montantEncaisse(BigDecimal.valueOf(encaisse))
                .statut(statut)
                .build();
    }

    private LigneCreance creance(TypeDocumentCreance type, Long id, int restant, LocalDate date) {
        return LigneCreance.builder()
                .document(type).documentId(id)
                .chauffeurId(CHAUFFEUR).vehiculeId(VEHICULE)
                .dateReference(date)
                .montantDu(BigDecimal.valueOf(restant))
                .montantRegle(BigDecimal.ZERO)
                .restant(BigDecimal.valueOf(restant))
                .build();
    }

    private void cotisations(LigneCotisation... lignes) {
        when(ligneCotisationRepository.findByCriteres(any())).thenReturn(List.of(lignes));
    }

    private void creances(LigneCreance... lignes) {
        when(creanceRepository.getLignesCreance(CHAUFFEUR)).thenReturn(List.of(lignes));
    }

    private DecompteBeneficiaire calculerChauffeur() {
        List<DecompteBeneficiaire> decomptes =
                useCase.calculer(PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN);
        assertThat(decomptes).hasSize(1);
        return decomptes.get(0);
    }

    // ── Fonds ───────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Le fonds est la somme des cotisations réellement encaissées")
    void fonds_somme_des_encaissements() {
        cotisations(cotisation(1L, 1_000, StatutLigneCotisation.ENCAISSE),
                cotisation(2L, 400, StatutLigneCotisation.PARTIELLEMENT_ENCAISSE));

        DecompteBeneficiaire decompte = calculerChauffeur();

        assertThat(decompte.getFond()).isEqualByComparingTo("1400");
        assertThat(decompte.getNet()).isEqualByComparingTo("1400");
        assertThat(decompte.getChauffeurNom()).isEqualTo("Aya Kouassi");
    }

    @Test
    @DisplayName("Une cotisation jamais versée n'entre pas dans le fonds")
    void cotisation_non_versee_exclue() {
        cotisations(cotisation(1L, 1_000, StatutLigneCotisation.ENCAISSE),
                cotisation(2L, 0, StatutLigneCotisation.EN_ATTENTE));

        assertThat(calculerChauffeur().getFond()).isEqualByComparingTo("1000");
    }

    @ParameterizedTest(name = "cotisation {0} exclue du fonds")
    @EnumSource(value = StatutLigneCotisation.class, names = {"ANNULEE", "RESTITUEE"})
    @DisplayName("Une cotisation annulée ou déjà restituée n'entre pas dans le fonds")
    void statuts_exclus(StatutLigneCotisation statut) {
        cotisations(cotisation(1L, 1_000, StatutLigneCotisation.ENCAISSE),
                cotisation(2L, 500, statut));

        assertThat(calculerChauffeur().getFond()).isEqualByComparingTo("1000");
    }

    // ── Compensation ────────────────────────────────────────────────────────

    @Test
    @DisplayName("Le fonds éteint les créances des plus anciennes aux plus récentes")
    void compensation_par_anteriorite() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        creances(
                creance(TypeDocumentCreance.RECETTE, 100L, 6_000, DEBUT.minusDays(30)),
                creance(TypeDocumentCreance.PENALITE, 200L, 5_000, DEBUT.minusDays(10)));

        DecompteBeneficiaire decompte = calculerChauffeur();

        // 10 000 de fonds : la plus ancienne créance est soldée (6 000), la
        // suivante n'est couverte qu'à hauteur du reste (4 000).
        assertThat(decompte.getAllocations()).hasSize(2);
        assertThat(decompte.getAllocations().get(0).getMontant()).isEqualByComparingTo("6000");
        assertThat(decompte.getAllocations().get(1).getMontant()).isEqualByComparingTo("4000");
        assertThat(decompte.getTotalCompense()).isEqualByComparingTo("10000");
        assertThat(decompte.getNet()).isEqualByComparingTo("0");
        // Reliquat : la part de créance non couverte reste due.
        assertThat(decompte.getReliquat()).isEqualByComparingTo("1000");
    }

    @Test
    @DisplayName("Un fonds supérieur aux créances laisse un net à restituer")
    void net_a_restituer() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        creances(creance(TypeDocumentCreance.RECETTE, 100L, 3_000, DEBUT.minusDays(30)));

        DecompteBeneficiaire decompte = calculerChauffeur();

        assertThat(decompte.getTotalCompense()).isEqualByComparingTo("3000");
        assertThat(decompte.getNet()).isEqualByComparingTo("7000");
        assertThat(decompte.getReliquat()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("Sans fonds, aucune créance n'est compensée mais le reliquat reste dû")
    void aucun_fonds() {
        creances(creance(TypeDocumentCreance.RECETTE, 100L, 3_000, DEBUT.minusDays(30)));

        DecompteBeneficiaire decompte = calculerChauffeur();

        assertThat(decompte.getFond()).isEqualByComparingTo("0");
        assertThat(decompte.getAllocations()).isEmpty();
        assertThat(decompte.getReliquat()).isEqualByComparingTo("3000");
    }

    @Test
    @DisplayName("Les cotisations ne sont jamais comptées deux fois comme créances")
    void cotisations_exclues_des_creances() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        creances(
                creance(TypeDocumentCreance.COTISATION, 300L, 2_000, DEBUT.minusDays(5)),
                creance(TypeDocumentCreance.RECETTE, 100L, 3_000, DEBUT.minusDays(30)));

        DecompteBeneficiaire decompte = calculerChauffeur();

        // Seule la recette impayée est compensée : une cotisation impayée n'est
        // simplement pas dans le fonds, la compter en créance la doublerait.
        assertThat(decompte.getAllocations()).hasSize(1);
        assertThat(decompte.getTotalCompense()).isEqualByComparingTo("3000");
    }

    @Test
    @DisplayName("Une créance déjà soldée n'est pas compensée")
    void creance_soldee_ignoree() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        LigneCreance soldee = creance(TypeDocumentCreance.RECETTE, 100L, 0, DEBUT.minusDays(30));
        when(creanceRepository.getLignesCreance(CHAUFFEUR)).thenReturn(List.of(soldee));

        assertThat(calculerChauffeur().getAllocations()).isEmpty();
    }

    // ── Périmètre et sélection ──────────────────────────────────────────────

    @Test
    @DisplayName("Sur un périmètre véhicule, seules les créances de ce véhicule sont compensées")
    void perimetre_vehicule_filtre_les_creances() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        LigneCreance autreVehicule = creance(TypeDocumentCreance.RECETTE, 101L, 4_000, DEBUT.minusDays(20));
        autreVehicule.setVehiculeId(99L);
        when(creanceRepository.getLignesCreance(CHAUFFEUR)).thenReturn(List.of(
                creance(TypeDocumentCreance.RECETTE, 100L, 3_000, DEBUT.minusDays(30)),
                autreVehicule));

        List<DecompteBeneficiaire> decomptes =
                useCase.calculer(PerimetreArrete.VEHICULE, VEHICULE, DEBUT, FIN);

        assertThat(decomptes).hasSize(1);
        assertThat(decomptes.get(0).getTotalCompense()).isEqualByComparingTo("3000");
    }

    @Test
    @DisplayName("Un arrêté partiel ne restitue que les cotisations sélectionnées")
    void selection_partielle_des_cotisations() {
        cotisations(cotisation(1L, 1_000, StatutLigneCotisation.ENCAISSE),
                cotisation(2L, 4_000, StatutLigneCotisation.ENCAISSE));

        List<DecompteBeneficiaire> decomptes = useCase.calculer(
                PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN,
                new SelectionArrete(Set.of(2L), null));

        assertThat(decomptes.get(0).getFond()).isEqualByComparingTo("4000");
        assertThat(decomptes.get(0).getCotisations()).extracting(LigneCotisation::getId)
                .containsExactly(2L);
    }

    @Test
    @DisplayName("Un arrêté partiel ne compense que les créances sélectionnées")
    void selection_partielle_des_creances() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        creances(
                creance(TypeDocumentCreance.RECETTE, 100L, 3_000, DEBUT.minusDays(30)),
                creance(TypeDocumentCreance.PENALITE, 200L, 5_000, DEBUT.minusDays(10)));

        List<DecompteBeneficiaire> decomptes = useCase.calculer(
                PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN,
                new SelectionArrete(null, Set.of(
                        new SelectionArrete.CreanceKey(TypeDocumentCreance.PENALITE, 200L))));

        assertThat(decomptes.get(0).getTotalCompense()).isEqualByComparingTo("5000");
        assertThat(decomptes.get(0).getNet()).isEqualByComparingTo("5000");
    }

    @Test
    @DisplayName("Une sélection sans aucune créance ne compense rien")
    void selection_sans_creance() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        creances(creance(TypeDocumentCreance.RECETTE, 100L, 3_000, DEBUT.minusDays(30)));

        List<DecompteBeneficiaire> decomptes = useCase.calculer(
                PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN,
                new SelectionArrete(null, Set.of()));

        assertThat(decomptes.get(0).getTotalCompense()).isEqualByComparingTo("0");
        assertThat(decomptes.get(0).getNet()).isEqualByComparingTo("10000");
    }

    @Test
    @DisplayName("La période demandée est transmise au filtre des cotisations")
    void periode_transmise() {
        useCase.calculer(PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN);

        org.mockito.ArgumentCaptor<LigneCotisationFiltres> capture =
                org.mockito.ArgumentCaptor.forClass(LigneCotisationFiltres.class);
        org.mockito.Mockito.verify(ligneCotisationRepository).findByCriteres(capture.capture());

        assertThat(capture.getValue().getChauffeurId()).isEqualTo(CHAUFFEUR);
        assertThat(capture.getValue().getDateDebut()).isEqualTo(DEBUT);
        assertThat(capture.getValue().getDateFin()).isEqualTo(FIN);
    }

    @Test
    @DisplayName("Un chauffeur sans fonds ni créance ne figure pas au décompte")
    void decompte_vide_ecarte() {
        assertThat(useCase.calculer(PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN)).isEmpty();
    }

    @Test
    @DisplayName("Un chauffeur inconnu du référentiel garde un libellé lisible")
    void nom_de_repli() {
        when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.empty());
        LigneCotisation cotisation = cotisation(1L, 1_000, StatutLigneCotisation.ENCAISSE);
        cotisation.setChauffeurNom("Konan B.");
        cotisations(cotisation);

        assertThat(calculerChauffeur().getChauffeurNom()).isEqualTo("Konan B.");
    }

    @Test
    @DisplayName("Sans aucun nom disponible, le décompte affiche l'identifiant")
    void nom_de_dernier_recours() {
        when(chauffeurRepository.findById(CHAUFFEUR)).thenReturn(Optional.empty());
        cotisations(cotisation(1L, 1_000, StatutLigneCotisation.ENCAISSE));

        assertThat(calculerChauffeur().getChauffeurNom()).isEqualTo("Chauffeur #1");
    }

    // ── Aperçu ──────────────────────────────────────────────────────────────

    @Test
    @DisplayName("L'aperçu porte les cotisations au crédit et les compensations au débit")
    void apercu_sens_des_lignes() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        creances(creance(TypeDocumentCreance.RECETTE, 100L, 3_000, DEBUT.minusDays(30)));

        ArreteCompte apercu = useCase.construireApercu(
                PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN);

        assertThat(apercu.getId()).isNull(); // aperçu non persisté
        assertThat(apercu.getPerimetre()).isEqualTo(PerimetreArrete.CHAUFFEUR);
        assertThat(apercu.getPeriodeDebut()).isEqualTo(DEBUT);
        assertThat(apercu.getPeriodeFin()).isEqualTo(FIN);

        assertThat(apercu.getLignes()).hasSize(2);
        assertThat(apercu.getLignes()).filteredOn(l -> l.getSens() == SensArrete.CREDIT)
                .singleElement().extracting(LigneArrete::getMontant)
                .isEqualTo(BigDecimal.valueOf(10_000));
        assertThat(apercu.getLignes()).filteredOn(l -> l.getSens() == SensArrete.DEBIT)
                .singleElement().extracting(LigneArrete::getMontant)
                .isEqualTo(BigDecimal.valueOf(3_000));
    }

    @Test
    @DisplayName("L'aperçu récapitule le règlement par bénéficiaire")
    void apercu_reglement() {
        cotisations(cotisation(1L, 10_000, StatutLigneCotisation.ENCAISSE));
        creances(creance(TypeDocumentCreance.RECETTE, 100L, 3_000, DEBUT.minusDays(30)));

        ArreteCompte apercu = useCase.construireApercu(
                PerimetreArrete.CHAUFFEUR, CHAUFFEUR, DEBUT, FIN);

        assertThat(apercu.getReglements()).singleElement().satisfies(r -> {
            assertThat(r.getChauffeurId()).isEqualTo(CHAUFFEUR);
            assertThat(r.getChauffeurNom()).isEqualTo("Aya Kouassi");
            assertThat(r.getTotalCotisations()).isEqualByComparingTo("10000");
            assertThat(r.getTotalCreancesCompensees()).isEqualByComparingTo("3000");
            assertThat(r.getMontantNet()).isEqualByComparingTo("7000");
            assertThat(r.getReliquatReporte()).isEqualByComparingTo("0");
        });
    }
}
