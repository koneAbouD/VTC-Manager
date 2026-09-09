package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Ce qui ferme la correction d'une date de versement.
 *
 * <p>Trois portes, dans l'ordre où le service les pousse : la ligne (annulée,
 * ou déjà prise dans un arrêté de compte), le versement lui-même (extourné, ou
 * couvert par un arrêté à sa date), et la date visée. Les deux premières
 * suffisent à fermer la fiche entière ; la troisième ne se juge qu'au moment de
 * l'écriture, puisqu'elle dépend du jour choisi.
 */
class ModificationDateEncaissementServiceTest {

    private static final LocalDate LE_10_AOUT = LocalDate.of(2026, 8, 10);
    private static final Long CAISSE = 1L;
    private static final Long BANQUE = 2L;

    private VerrouArreteService verrouArreteService;
    private ArreteCompteRepository arreteCompteRepository;
    private ModificationDateEncaissementService service;

    @BeforeEach
    void setUp() {
        verrouArreteService = mock(VerrouArreteService.class);
        arreteCompteRepository = mock(ArreteCompteRepository.class);
        CompteTresorerieResolver compteTresorerieResolver = mock(CompteTresorerieResolver.class);

        arretes(null, null, Map.of());
        when(arreteCompteRepository.existeLigneValidePourDocument(any(), anyLong()))
                .thenReturn(false);
        when(compteTresorerieResolver.resoudre(null, ModePaiement.ESPECES)).thenReturn(CAISSE);
        when(compteTresorerieResolver.resoudre(null, ModePaiement.MOBILE_MONEY)).thenReturn(BANQUE);

        service = new ModificationDateEncaissementService(verrouArreteService,
                arreteCompteRepository, compteTresorerieResolver);
    }

    /** Instantané des arrêtés vu par le service. */
    private void arretes(LocalDate finPeriode, LocalDate derniereCaisse,
                         Map<Long, LocalDate> parCompte) {
        when(verrouArreteService.verrous()).thenReturn(
                new VerrouArreteService.Verrous(finPeriode, derniereCaisse, parCompte));
    }

    private LigneRecette recette(StatutLigneRecette statut, Encaissement... versements) {
        return LigneRecette.builder()
                .id(7L)
                .dateRecette(LE_10_AOUT)
                .montantAttendu(new BigDecimal("15000"))
                .montantEncaisse(new BigDecimal("15000"))
                .statut(statut)
                .encaissements(new java.util.ArrayList<>(List.of(versements)))
                .build();
    }

    private Encaissement versement(LocalDate date, ModePaiement mode) {
        return Encaissement.builder()
                .id(1L).ligneRecetteId(7L).montant(new BigDecimal("15000"))
                .modeEncaissement(mode).dateEncaissement(date).build();
    }

    private LigneCotisation cotisation(StatutLigneCotisation statut, Long arreteId) {
        return LigneCotisation.builder()
                .id(9L)
                .dateCotisation(LE_10_AOUT)
                .montantDu(new BigDecimal("2000"))
                .montantEncaisse(new BigDecimal("2000"))
                .statut(statut)
                .arreteId(arreteId)
                .encaissements(new java.util.ArrayList<>(List.of(
                        EncaissementCotisation.builder()
                                .id(3L).ligneCotisationId(9L).montant(new BigDecimal("2000"))
                                .modeEncaissement(ModePaiement.ESPECES)
                                .dateEncaissement(LE_10_AOUT).build())))
                .build();
    }

    private LignePenalite penalite(StatutLignePenalite statut) {
        return LignePenalite.builder()
                .id(11L)
                .typeSanction(TypeSanction.AMENDE)
                .dateFaute(LE_10_AOUT)
                .montant(new BigDecimal("5000"))
                .montantEncaisse(new BigDecimal("5000"))
                .statut(statut)
                .encaissements(new java.util.ArrayList<>(List.of(
                        EncaissementPenalite.builder()
                                .id(6L).lignePenaliteId(11L).montant(new BigDecimal("5000"))
                                .modeEncaissement(ModePaiement.ESPECES)
                                .dateEncaissement(LE_10_AOUT).build())))
                .build();
    }

    // ── Famille 1 : la ligne ────────────────────────────────────────────────

    @Test
    @DisplayName("Livres ouverts : la date d'un versement se corrige")
    void rien_ne_ferme() {
        LigneRecette ligne = recette(StatutLigneRecette.ENCAISSE,
                versement(LE_10_AOUT, ModePaiement.ESPECES));

        service.marquerVersements(ligne);

        assertThat(ligne.getEncaissements().get(0).getDateModifiable()).isTrue();
        assertThat(ligne.getEncaissements().get(0).getMotifDateNonModifiable()).isNull();
    }

    @Test
    @DisplayName("Recette annulée : ses versements ne comptent plus, la date non plus")
    void recette_annulee() {
        LigneRecette ligne = recette(StatutLigneRecette.ANNULEE,
                versement(LE_10_AOUT, ModePaiement.ESPECES));

        assertThat(service.motifBlocage(ligne)).contains("annulée");
        assertThatThrownBy(() -> service.verifierLigne(ligne))
                .isInstanceOf(EcritureFigeeException.class);
    }

    @Test
    @DisplayName("Recette déjà compensée par un arrêté : le décompte est parti avec ses dates")
    void recette_arretee() {
        when(arreteCompteRepository.existeLigneValidePourDocument(
                TypeDocumentCreance.RECETTE, 7L)).thenReturn(true);
        LigneRecette ligne = recette(StatutLigneRecette.ENCAISSE,
                versement(LE_10_AOUT, ModePaiement.ESPECES));

        service.marquerVersements(ligne);

        assertThat(ligne.getEncaissements().get(0).getDateModifiable()).isFalse();
        assertThat(ligne.getEncaissements().get(0).getMotifDateNonModifiable())
                .contains("arrêté de compte");
    }

    @Test
    @DisplayName("Cotisation restituée : le dépôt est rendu, ses dates sont figées")
    void cotisation_restituee() {
        LigneCotisation ligne = cotisation(StatutLigneCotisation.RESTITUEE, 4L);

        assertThat(service.motifBlocage(ligne)).contains("restitué");
        assertThatThrownBy(() -> service.verifierLigne(ligne))
                .isInstanceOf(EcritureFigeeException.class);
    }

    @Test
    @DisplayName("Cotisation partiellement rendue : l'arrêté rattaché la ferme aussi")
    void cotisation_partiellement_restituee() {
        LigneCotisation ligne = cotisation(StatutLigneCotisation.PARTIELLEMENT_ENCAISSE, 4L);

        service.marquerVersements(ligne);

        assertThat(ligne.getEncaissements().get(0).getDateModifiable()).isFalse();
    }

    @Test
    @DisplayName("Cotisation ordinaire : la date de son versement se corrige")
    void cotisation_ouverte() {
        LigneCotisation ligne = cotisation(StatutLigneCotisation.ENCAISSE, null);

        service.marquerVersements(ligne);

        assertThat(ligne.getEncaissements().get(0).getDateModifiable()).isTrue();
    }

    @Test
    @DisplayName("Pénalité annulée : ses versements ne comptent plus, la date non plus")
    void penalite_annulee() {
        LignePenalite ligne = penalite(StatutLignePenalite.ANNULEE);

        assertThat(service.motifBlocage(ligne)).contains("annulée");
        assertThatThrownBy(() -> service.verifierLigne(ligne))
                .isInstanceOf(EcritureFigeeException.class);
    }

    @Test
    @DisplayName("Pénalité déjà compensée par un arrêté : le décompte est parti avec ses dates")
    void penalite_arretee() {
        when(arreteCompteRepository.existeLigneValidePourDocument(
                TypeDocumentCreance.PENALITE, 11L)).thenReturn(true);
        LignePenalite ligne = penalite(StatutLignePenalite.ENCAISSEE);

        service.marquerVersements(ligne);

        assertThat(ligne.getEncaissements().get(0).getDateModifiable()).isFalse();
        assertThat(ligne.getEncaissements().get(0).getMotifDateNonModifiable())
                .contains("arrêté de compte");
    }

    @Test
    @DisplayName("Amende ordinaire : la date de son versement se corrige")
    void penalite_ouverte() {
        LignePenalite ligne = penalite(StatutLignePenalite.PARTIELLEMENT_ENCAISSEE);

        service.marquerVersements(ligne);

        assertThat(ligne.getEncaissements().get(0).getDateModifiable()).isTrue();
    }

    // ── Famille 2 : le versement ────────────────────────────────────────────

    @Test
    @DisplayName("Versement extourné : il ne compte plus, sa date n'a plus d'effet")
    void versement_extourne() {
        Encaissement extourne = versement(LE_10_AOUT, ModePaiement.ESPECES);
        extourne.setAnnuleLe(LocalDateTime.now());
        LigneRecette ligne = recette(StatutLigneRecette.ENCAISSE, extourne);

        service.marquerVersements(ligne);

        assertThat(extourne.getDateModifiable()).isFalse();
        assertThat(extourne.getMotifDateNonModifiable()).contains("extourné");
    }

    @Test
    @DisplayName("Période close : le versement qu'elle couvre ne bouge plus")
    void periode_close() {
        arretes(LocalDate.of(2026, 8, 31), null, Map.of());

        assertThat(service.motifBlocageVersement(LE_10_AOUT, CAISSE, false))
                .contains("période comptable clôturée");
    }

    @Test
    @DisplayName("Caisse comptée : seule la sienne fige le versement, pas celle d'à côté")
    void caisse_comptee() {
        arretes(null, LE_10_AOUT, Map.of(CAISSE, LE_10_AOUT));

        assertThat(service.motifBlocageVersement(LE_10_AOUT, CAISSE, false))
                .contains("La caisse a été comptée le 10/08/2026");
        assertThat(service.motifBlocageVersement(LE_10_AOUT, BANQUE, false)).isNull();
    }

    // ── Famille 3 : la date visée ───────────────────────────────────────────

    @Test
    @DisplayName("La date visée est jugée elle aussi : on ne déplace pas dans un mois clos")
    void nouvelle_date_dans_periode_close() {
        arretes(LocalDate.of(2026, 7, 31), null, Map.of());

        assertThat(service.motifBlocageNouvelleDate(LocalDate.of(2026, 7, 20), CAISSE))
                .contains("période comptable clôturée");
        assertThatThrownBy(() ->
                service.verifierNouvelleDate(LocalDate.of(2026, 7, 20), CAISSE))
                .isInstanceOf(EcritureFigeeException.class);
        // Le mois d'après reste ouvert.
        assertThat(service.motifBlocageNouvelleDate(LE_10_AOUT, CAISSE)).isNull();
    }

    @Test
    @DisplayName("Une écriture sans caisse connue n'est figée que par la période")
    void sans_compte() {
        arretes(null, LE_10_AOUT, Map.of(CAISSE, LE_10_AOUT));

        assertThat(service.motifBlocageVersement(LE_10_AOUT, null, false)).isNull();
        assertThat(service.motifBlocageNouvelleDate(LE_10_AOUT, null)).isNull();
    }
}
