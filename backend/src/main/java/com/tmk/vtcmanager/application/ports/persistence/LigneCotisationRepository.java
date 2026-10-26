package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.TotalCotisationParStatut;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface LigneCotisationRepository {

    LigneCotisation save(LigneCotisation ligne);

    Optional<LigneCotisation> findById(Long id);

    /**
     * Lecture verrouillée ({@code SELECT … FOR UPDATE}) jusqu'à la fin de la
     * transaction appelante, état relu en base même si la ligne y a déjà été
     * chargée. À utiliser avant tout contrôle du type « encaissé ≤ attendu »
     * suivi d'une écriture : deux encaissements simultanés de la même ligne
     * passent alors l'un après l'autre, et le second voit le premier.
     */
    Optional<LigneCotisation> findByIdPourMiseAJour(Long id);

    List<LigneCotisation> findByCriteres(LigneCotisationFiltres filtres);

    PageResult<LigneCotisation> findPageByCriteres(LigneCotisationFiltres filtres, int page, int size);

    /**
     * Cumuls par statut sur les mêmes filtres, <b>sans pagination</b> et en
     * ignorant {@link LigneCotisationFiltres#getStatut()} : les compteurs de
     * l'écran doivent rester lisibles quand un statut est sélectionné, sinon
     * tous les autres tomberaient à zéro.
     */
    List<TotalCotisationParStatut> totauxParStatut(LigneCotisationFiltres filtres);

    List<LigneCotisation> findByVehiculeIdAndDateCotisation(Long vehiculeId, LocalDate date);

    Optional<LigneCotisation> findActiveByVehiculeIdAndDate(Long vehiculeId, LocalDate date);

    Optional<LigneCotisation> findActiveByChauffeurIdAndDate(Long chauffeurId, LocalDate date);

    /** Cf. {@link LigneRecetteRepository#findByChauffeurIdAndDateRecette} : tous statuts. */
    List<LigneCotisation> findByChauffeurIdAndDateCotisation(Long chauffeurId, LocalDate date);

    /** Cf. {@link LigneRecetteRepository#findByDateRecette} : la journée entière, en une requête. */
    List<LigneCotisation> findByDateCotisation(LocalDate date);

    /** Change le titulaire du dépôt. Ni montant ni statut ne bougent. */
    void reaffecterChauffeur(Long ligneId, Long chauffeurId);

    void updateStatutAndMontantEncaisse(Long id, StatutLigneCotisation statut, BigDecimal montantEncaisse);

    /** Recalcule montant_encaisse + statut de la ligne depuis ses encaissements (source de vérité). */
    void recalculerDepuisEncaissements(Long ligneId);

    /**
     * Enregistre la part rendue par l'arrêté. La ligne ne bascule en RESTITUEE
     * que si elle était intégralement encaissée : ce qu'elle doit encore reste
     * une créance ouverte.
     */
    void marquerRestituee(Long ligneId, Long arreteId, BigDecimal montant);

    /** Annule la restitution (arrête annulé) : détache l'arrêté et recalcule le statut depuis le montant encaissé. */
    void annulerRestitution(Long ligneId, BigDecimal montant);

    void deleteById(Long id);
}
