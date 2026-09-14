package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.operation.SoldePeriode;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface OperationFinanciereRepository {

    OperationFinanciere save(OperationFinanciere operation);

    Optional<OperationFinanciere> findById(Long id);

    List<OperationFinanciere> findByCriteres(OperationFinanciereFiltres filtres);

    /**
     * Agrège revenus / dépenses sur la période [debut, fin] (bornes incluses,
     * nullables = pas de borne), opérations annulées exclues.
     */
    SoldePeriode calculerSolde(LocalDate debut, LocalDate fin);

    PageResult<OperationFinanciere> findPageByCriteres(OperationFinanciereFiltres filtres, int page, int size);

    List<OperationFinanciere> findByChauffeurId(Long chauffeurId);

    List<OperationFinanciere> findByVehiculeId(Long vehiculeId);

    /** Règlements passés sur une facture fournisseur, du plus ancien au plus récent. */
    List<OperationFinanciere> findByFacturePartenaireId(Long factureId);

    /**
     * Passe au nouveau tiers les écritures d'encaissement d'une ligne dont la
     * créance vient de changer de débiteur, et renvoie leur nombre.
     *
     * <p>Seules les écritures <b>vivantes</b> suivent : une opération déjà
     * extournée ne se modifie plus — c'est la règle de
     * {@code ModificationEcritureGuard} — et le couple qu'elle forme avec son
     * origine s'annule de toute façon, laissant le solde du chauffeur intact.
     *
     * @param typeLigne RECETTE ou COTISATION : dit quelle table d'encaissements lire
     */
    int reaffecterChauffeurDesEncaissements(TypeDocumentCreance typeLigne, Long ligneId,
                                            Long chauffeurId, String auteur);

    /** Rassemble ces écritures sous un même versement. */
    void rattacherAuVersement(List<Long> operationIds, UUID versementId);

    /**
     * Défait un versement : ses écritures redeviennent isolées. Appelé quand
     * une correction fait qu'elles ne décrivent plus le même billet.
     */
    void detacherVersement(UUID versementId);

    /**
     * Défait les versements auxquels appartiennent les écritures d'une ligne —
     * celle dont le chauffeur va changer.
     *
     * @param typeLigne RECETTE ou COTISATION : dit quelle table d'encaissements lire
     */
    void detacherVersementsDesEncaissements(TypeDocumentCreance typeLigne, Long ligneId);

    /** Écritures d'un versement, dans l'ordre de leur création. */
    List<OperationFinanciere> findByVersementId(UUID versementId);

    boolean existsByReference(String reference);

    void deleteById(Long id);
}
