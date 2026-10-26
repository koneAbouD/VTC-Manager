package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface LigneRecetteRepository {

    LigneRecette save(LigneRecette ligne);

    Optional<LigneRecette> findById(Long id);

    /**
     * Lecture verrouillée ({@code SELECT … FOR UPDATE}) jusqu'à la fin de la
     * transaction appelante, état relu en base même si la ligne y a déjà été
     * chargée. À utiliser avant tout contrôle du type « encaissé ≤ attendu »
     * suivi d'une écriture : deux encaissements simultanés de la même ligne
     * passent alors l'un après l'autre, et le second voit le premier.
     */
    Optional<LigneRecette> findByIdPourMiseAJour(Long id);

    List<LigneRecette> findByCriteres(LigneRecetteFiltres filtres);

    PageResult<LigneRecette> findPageByCriteres(LigneRecetteFiltres filtres, int page, int size);

    boolean existsByVehiculeIdAndChauffeurIdAndDateRecette(Long vehiculeId, Long chauffeurId, LocalDate date);

    Optional<LigneRecette> findByVehiculeIdAndChauffeurIdAndDateRecette(Long vehiculeId, Long chauffeurId, LocalDate date);

    List<LigneRecette> findByVehiculeIdAndDateRecette(Long vehiculeId, LocalDate date);

    Optional<LigneRecette> findActiveByVehiculeIdAndDate(Long vehiculeId, LocalDate date);

    Optional<LigneRecette> findActiveByChauffeurIdAndDate(Long chauffeurId, LocalDate date);

    /**
     * Toutes les lignes d'un chauffeur ce jour-là, <b>quel que soit leur
     * statut</b> : les vivantes disent sur quel véhicule il roulait, les
     * annulées signalent le doublon que la contrainte d'unicité refuserait.
     */
    List<LigneRecette> findByChauffeurIdAndDateRecette(Long chauffeurId, LocalDate date);

    /**
     * Toutes les lignes d'une journée, tous chauffeurs et tous statuts. Juger
     * trente candidats un par un coûterait soixante requêtes ; on lit la journée
     * une fois et chacun se juge en mémoire — comme
     * {@code VerrouArreteService.Verrous} le fait déjà pour les arrêtés.
     */
    List<LigneRecette> findByDateRecette(LocalDate date);

    /** Change le débiteur de la ligne. Ni montant ni statut ne bougent. */
    void reaffecterChauffeur(Long ligneId, Long chauffeurId);

    void updateStatutAndMontantEncaisse(Long id, StatutLigneRecette statut, java.math.BigDecimal montantEncaisse);

    /** Recalcule montant_encaisse + statut de la ligne depuis ses encaissements (source de vérité). */
    void recalculerDepuisEncaissements(Long ligneId);

    /** Corrige le montant attendu ; le statut est à recalculer ensuite. */
    void modifierMontantAttendu(Long ligneId, java.math.BigDecimal montant);

    void deleteById(Long id);
}
