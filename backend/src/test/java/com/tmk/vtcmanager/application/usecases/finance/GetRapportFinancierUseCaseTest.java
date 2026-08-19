package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.finance.GroupByRapport;
import com.tmk.vtcmanager.application.domain.finance.RapportFinancier;
import com.tmk.vtcmanager.application.domain.finance.RapportFinancier.LigneRepartition;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.NatureResultat;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Une écriture annulée n'est pas retirée du journal : elle y reste, avec son
 * statut ENCAISSE/PAYE, et reçoit une contre-passation de même type, même
 * catégorie et même statut, au montant opposé. Les deux franchissent donc le
 * filtre « opérations terminées » du rapport, et c'est le signe — lui seul —
 * qui les annule. Les sommer en valeur absolue comptait la dépense annulée
 * deux fois.
 */
class GetRapportFinancierUseCaseTest {

    private static final YearMonth MOIS = YearMonth.of(2026, 8);
    private static final YearMonth MOIS_PRECEDENT = MOIS.minusMonths(1);

    private static final CategorieOperation CARBURANT = charge("CARBURANT", "Carburant");
    private static final CategorieOperation ENTRETIEN = charge("ENTRETIEN", "Entretien");
    private static final CategorieOperation RECETTES = CategorieOperation.builder()
            .code("ENCAISSEMENT_RECETTES").libelle("Encaissement recettes")
            .typeOperation(TypeOperation.REVENU)
            .natureResultat(NatureResultat.PRODUIT_EXPLOITATION)
            .build();

    private final AtomicLong sequenceId = new AtomicLong();

    private List<OperationFinanciere> duMois = List.of();
    private List<OperationFinanciere> duMoisPrecedent = List.of();
    private GetRapportFinancierUseCase useCase;

    @BeforeEach
    void setUp() {
        OperationFinanciereRepository operationRepository = mock(OperationFinanciereRepository.class);
        // Le use case interroge le dépôt deux fois — mois demandé puis mois
        // précédent — avec les mêmes filtres à la date près. On répond d'après
        // la borne de début, comme le ferait la requête.
        when(operationRepository.findByCriteres(any())).thenAnswer(invocation -> {
            LocalDate debut = invocation.<OperationFinanciereFiltres>getArgument(0).debut();
            if (MOIS_PRECEDENT.atDay(1).equals(debut)) return duMoisPrecedent;
            if (MOIS.atDay(1).equals(debut)) return duMois;
            return List.of();
        });
        useCase = new GetRapportFinancierUseCase(operationRepository);
    }

    // ── Le cas qui motive tout : l'extourne dans le mois ──────────────────

    @Test
    @DisplayName("Une dépense extournée dans le mois ne pèse plus rien au total")
    void depenseExtourneeNeutralisee() {
        OperationFinanciere depense = depense(CARBURANT, 50_000);
        journal(List.of(depense, extourneDe(depense)), List.of());

        RapportFinancier rapport = executer(GroupByRapport.CHAUFFEUR);

        assertThat(rapport.getTotalDepenses()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("La catégorie entièrement extournée disparaît de la répartition")
    void categorieEntierementExtourneeMasquee() {
        OperationFinanciere carburant = depense(CARBURANT, 50_000);
        journal(List.of(carburant, extourneDe(carburant), depense(ENTRETIEN, 30_000)), List.of());

        RapportFinancier rapport = executer(GroupByRapport.CHAUFFEUR);

        assertThat(rapport.getTotalDepenses()).isEqualByComparingTo("30000");
        assertThat(rapport.getBreakdownDepenses())
                .extracting(LigneRepartition::getLabel)
                .containsExactly("Entretien");
        assertThat(rapport.getBreakdownDepenses().get(0).getPourcentage())
                .isEqualByComparingTo("100.0");
    }

    @Test
    @DisplayName("Côté revenus, l'extourne ne retire que la part du chauffeur concerné")
    void extourneNAffecteQueSonGroupe() {
        Chauffeur kone = chauffeur(1L, "Ali", "Koné");
        Chauffeur traore = chauffeur(2L, "Sita", "Traoré");
        OperationFinanciere recetteKone = revenu(RECETTES, 100_000, kone);
        journal(List.of(recetteKone, extourneDe(recetteKone), revenu(RECETTES, 60_000, traore)),
                List.of());

        RapportFinancier rapport = executer(GroupByRapport.CHAUFFEUR);

        assertThat(rapport.getTotalRevenus()).isEqualByComparingTo("60000");
        assertThat(rapport.getBreakdownRevenus())
                .extracting(LigneRepartition::getLabel)
                .containsExactly("Sita Traoré");
    }

    // ── L'extourne d'un mois antérieur, qui pèse sur le mois décidé ───────

    @Test
    @DisplayName("Une extourne venue d'un mois clos allège le mois où elle est passée")
    void extourneDUnMoisAnterieur() {
        // L'origine appartient à juillet : seule la contre-passation, datée
        // d'août, entre dans le périmètre du rapport d'août.
        OperationFinanciere origineDeJuillet = depense(CARBURANT, 50_000);
        origineDeJuillet.setDateOperation(MOIS_PRECEDENT.atDay(20));
        OperationFinanciere extourne = extourneDe(origineDeJuillet);
        extourne.setDateOperation(MOIS.atDay(3));
        journal(List.of(extourne, depense(ENTRETIEN, 30_000)), List.of(origineDeJuillet));

        RapportFinancier rapport = executer(GroupByRapport.CHAUFFEUR);

        assertThat(rapport.getTotalDepenses()).isEqualByComparingTo("-20000");
        // Le total négatif ne retourne pas le signe des parts : la charge reste
        // positive, la contre-passation reste négative.
        assertThat(rapport.getBreakdownDepenses())
                .extracting(LigneRepartition::getLabel, LigneRepartition::getMontant,
                        LigneRepartition::getPourcentage)
                .containsExactly(
                        tuple("Entretien",
                                BigDecimal.valueOf(30_000), new BigDecimal("150.0")),
                        tuple("Carburant",
                                BigDecimal.valueOf(-50_000), new BigDecimal("-250.0")));
    }

    // ── Variations sur le mois précédent ──────────────────────────────────

    @Test
    @DisplayName("Le mois précédent entièrement extourné ne fait pas exploser la variation")
    void variationSurMoisPrecedentNeutralise() {
        OperationFinanciere depenseDeJuillet = depense(CARBURANT, 100_000);
        journal(List.of(depense(CARBURANT, 40_000)),
                List.of(depenseDeJuillet, extourneDe(depenseDeJuillet)));

        RapportFinancier rapport = executer(GroupByRapport.CHAUFFEUR);

        // Base nulle : aucune évolution calculable, et surtout aucune division
        // par zéro ni pourcentage aberrant.
        assertThat(rapport.getVariationDepensesPct()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("Une base négative ne retourne pas le sens de la variation")
    void variationSurBasePrecedenteNegative() {
        OperationFinanciere origine = depense(CARBURANT, 50_000);
        origine.setDateOperation(MOIS_PRECEDENT.minusMonths(1).atDay(10));
        OperationFinanciere extourne = extourneDe(origine);
        extourne.setDateOperation(MOIS_PRECEDENT.atDay(4));
        // Juillet : 30 000 dépensés, moins l'extourne de 50 000 venue de juin,
        // soit une base de −20 000.
        journal(List.of(depense(CARBURANT, 10_000)),
                List.of(extourne, depense(ENTRETIEN, 30_000)));

        RapportFinancier rapport = executer(GroupByRapport.CHAUFFEUR);

        // 10 000 contre −20 000 : les dépenses ont bien augmenté de 150 %.
        assertThat(rapport.getVariationDepensesPct()).isEqualByComparingTo("150.0");
    }

    // ── Liste détaillée ───────────────────────────────────────────────────

    @Test
    @DisplayName("Le journal conserve les deux écritures, signées et marquées")
    void listeConserveOrigineEtExtourne() {
        OperationFinanciere depense = depense(CARBURANT, 50_000);
        journal(List.of(depense, extourneDe(depense)), List.of());

        RapportFinancier rapport = executer(GroupByRapport.CHAUFFEUR);

        assertThat(rapport.getListeOperations())
                .extracting(RapportFinancier.LigneOperation::getMontant,
                        RapportFinancier.LigneOperation::isEstUneExtourne,
                        RapportFinancier.LigneOperation::isEstExtournee)
                .containsExactly(
                        tuple(BigDecimal.valueOf(50_000), false, true),
                        tuple(BigDecimal.valueOf(-50_000), true, false));
    }

    // ── Fixtures ──────────────────────────────────────────────────────────

    private RapportFinancier executer(GroupByRapport groupBy) {
        return useCase.executer(MOIS.getYear(), MOIS.getMonthValue(), groupBy);
    }

    /** Ce que le journal contient, du mois demandé et du mois précédent. */
    private void journal(List<OperationFinanciere> duMois,
                         List<OperationFinanciere> duMoisPrecedent) {
        this.duMois = duMois;
        this.duMoisPrecedent = duMoisPrecedent;
    }

    private static CategorieOperation charge(String code, String libelle) {
        return CategorieOperation.builder()
                .code(code).libelle(libelle)
                .typeOperation(TypeOperation.DEPENSE)
                .natureResultat(NatureResultat.CHARGE_VARIABLE)
                .build();
    }

    private static Chauffeur chauffeur(Long id, String prenom, String nom) {
        return Chauffeur.builder().id(id).prenom(prenom).nom(nom).build();
    }

    private OperationFinanciere depense(CategorieOperation categorie, int montant) {
        return operation(TypeOperation.DEPENSE, StatutOperation.PAYE, categorie, montant, null);
    }

    private OperationFinanciere revenu(CategorieOperation categorie, int montant, Chauffeur chauffeur) {
        return operation(TypeOperation.REVENU, StatutOperation.ENCAISSE, categorie, montant, chauffeur);
    }

    private OperationFinanciere operation(TypeOperation type, StatutOperation statut,
                                          CategorieOperation categorie, int montant,
                                          Chauffeur chauffeur) {
        return OperationFinanciere.builder()
                .id(sequenceId.incrementAndGet())
                .reference("OP-" + sequenceId.get())
                .typeOperation(type)
                .statut(statut)
                .categorie(categorie)
                .chauffeur(chauffeur)
                .montant(BigDecimal.valueOf(montant))
                .dateOperation(MOIS.atDay(15))
                .build();
    }

    /**
     * Contre-passation telle que la produit {@code AnnulerOperationFinanciereUseCase} :
     * mêmes type, catégorie, chauffeur et statut que l'origine — le statut terminal
     * compris —, montant opposé, et l'origine marquée annulée.
     */
    private OperationFinanciere extourneDe(OperationFinanciere origine) {
        origine.setAnnuleLe(origine.getDateOperation().plusDays(5).atTime(9, 0));
        origine.setMotifAnnulation("Saisie en double");
        return OperationFinanciere.builder()
                .id(sequenceId.incrementAndGet())
                .reference("EXT-" + sequenceId.get())
                .typeOperation(origine.getTypeOperation())
                .statut(origine.getStatut())
                .categorie(origine.getCategorie())
                .chauffeur(origine.getChauffeur())
                .vehicule(origine.getVehicule())
                .montant(origine.getMontant().negate())
                .dateOperation(origine.getDateOperation().plusDays(5))
                .extourneDeId(origine.getId())
                .build();
    }
}
