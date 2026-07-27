package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Les trois règles de modification d'une écriture : extournée, période close,
 * caisse comptée.
 */
class ModificationEcritureGuardTest {

    private static final Long COMPTE = 7L;
    private static final LocalDate LE_15_MARS = LocalDate.of(2026, 3, 15);

    private CloturePeriodeRepository cloturePeriodeRepository;
    private ClotureCaisseRepository clotureCaisseRepository;
    private ModificationEcritureGuard guard;

    @BeforeEach
    void setUp() {
        cloturePeriodeRepository = mock(CloturePeriodeRepository.class);
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.empty());
        when(clotureCaisseRepository.findDerniereDateCloture(anyLong())).thenReturn(Optional.empty());
        guard = new ModificationEcritureGuard(cloturePeriodeRepository, clotureCaisseRepository);
    }

    private OperationFinanciere ecriture(BigDecimal montant, LocalDate date) {
        return OperationFinanciere.builder()
                .id(1L)
                .typeOperation(TypeOperation.DEPENSE)
                .montant(montant)
                .modePaiement(ModePaiement.ESPECES)
                .compteTresorerieId(COMPTE)
                .dateOperation(date)
                .commentaire("Achat de pièces")
                .build();
    }

    private void caisseComptee(LocalDate date) {
        when(clotureCaisseRepository.findDerniereDateCloture(COMPTE)).thenReturn(Optional.of(date));
    }

    private void periodeClose(int annee, int mois) {
        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.of(
                CloturePeriode.builder().annee(annee).mois(mois)
                        .dateCloture(LocalDateTime.now()).build()));
    }

    @Test
    @DisplayName("Rien ne bloque quand les livres sont ouverts")
    void livres_ouverts_tout_est_modifiable() {
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        OperationFinanciere apres = ecriture(BigDecimal.valueOf(9000), LE_15_MARS);

        assertThatCode(() -> guard.verifier(avant, apres)).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Une écriture extournée n'est plus modifiable")
    void ecriture_extournee_figee() {
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        avant.setAnnuleLe(LocalDateTime.now());

        assertThatThrownBy(() -> guard.verifier(avant, ecriture(BigDecimal.valueOf(5000), LE_15_MARS)))
                .isInstanceOf(EcritureFigeeException.class)
                .hasMessageContaining("extournée");
    }

    @Test
    @DisplayName("Une extourne elle-même ne se modifie pas")
    void extourne_figee() {
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(-5000), LE_15_MARS);
        avant.setExtourneDeId(42L);

        assertThatThrownBy(() -> guard.verifier(avant, ecriture(BigDecimal.valueOf(-5000), LE_15_MARS)))
                .isInstanceOf(EcritureFigeeException.class);
    }

    @Test
    @DisplayName("Période close : même le commentaire est figé")
    void periode_close_bloque_tout() {
        periodeClose(2026, 3);
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        OperationFinanciere apres = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        apres.setCommentaire("Achat de pièces détachées");

        assertThatThrownBy(() -> guard.verifier(avant, apres))
                .isInstanceOf(EcritureFigeeException.class)
                .hasMessageContaining("période comptable clôturée");
    }

    @Test
    @DisplayName("Période close : on ne peut pas non plus y déplacer une écriture")
    void periode_close_bloque_la_date_visee() {
        periodeClose(2026, 3);
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(5000), LocalDate.of(2026, 4, 2));
        OperationFinanciere apres = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);

        assertThatThrownBy(() -> guard.verifier(avant, apres))
                .isInstanceOf(EcritureFigeeException.class);
    }

    @Test
    @DisplayName("Caisse comptée : le montant est figé")
    void caisse_comptee_bloque_le_montant() {
        caisseComptee(LE_15_MARS);
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        OperationFinanciere apres = ecriture(BigDecimal.valueOf(9000), LE_15_MARS);

        assertThatThrownBy(() -> guard.verifier(avant, apres))
                .isInstanceOf(EcritureFigeeException.class)
                .hasMessageContaining("comptée");
    }

    @Test
    @DisplayName("Caisse comptée : le commentaire reste corrigeable")
    void caisse_comptee_laisse_passer_le_commentaire() {
        caisseComptee(LE_15_MARS);
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        OperationFinanciere apres = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        apres.setCommentaire("Achat de pièces — facture 42");

        assertThatCode(() -> guard.verifier(avant, apres)).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Caisse comptée : changer de catégorie déplace des charges, donc c'est bloqué")
    void caisse_comptee_bloque_la_categorie() {
        caisseComptee(LE_15_MARS);
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        avant.setCategorie(CategorieOperation.builder().id(1L).build());
        OperationFinanciere apres = ecriture(BigDecimal.valueOf(5000), LE_15_MARS);
        apres.setCategorie(CategorieOperation.builder().id(2L).build());

        assertThatThrownBy(() -> guard.verifier(avant, apres))
                .isInstanceOf(EcritureFigeeException.class);
    }

    @Test
    @DisplayName("Un même montant écrit 5000 ou 5000.00 n'est pas une modification")
    void meme_montant_echelle_differente() {
        caisseComptee(LE_15_MARS);
        OperationFinanciere avant = ecriture(new BigDecimal("5000"), LE_15_MARS);
        OperationFinanciere apres = ecriture(new BigDecimal("5000.00"), LE_15_MARS);

        assertThatCode(() -> guard.verifier(avant, apres)).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Une écriture postérieure au dernier comptage reste modifiable")
    void apres_le_comptage_reste_ouvert() {
        caisseComptee(LE_15_MARS);
        OperationFinanciere avant = ecriture(BigDecimal.valueOf(5000), LocalDate.of(2026, 3, 16));
        OperationFinanciere apres = ecriture(BigDecimal.valueOf(9000), LocalDate.of(2026, 3, 16));

        assertThatCode(() -> guard.verifier(avant, apres)).doesNotThrowAnyException();
    }
}
