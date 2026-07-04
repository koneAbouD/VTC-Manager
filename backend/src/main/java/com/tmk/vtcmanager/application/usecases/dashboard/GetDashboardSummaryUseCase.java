package com.tmk.vtcmanager.application.usecases.dashboard;

import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.operation.NatureResultat;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.interfaces.rest.dashboard.dto.DashboardSummaryResponse;
import com.tmk.vtcmanager.interfaces.rest.dashboard.dto.OperationLigneDto;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

@RequiredArgsConstructor
public class GetDashboardSummaryUseCase {

    private final OperationFinanciereRepository operationRepository;
    private final VehiculeRepository vehiculeRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final MaintenanceRepository maintenanceRepository;
    private final DocumentRepository documentRepository;

    public DashboardSummaryResponse execute() {
        LocalDate today = LocalDate.now();
        LocalDate debutMois = today.withDayOfMonth(1);
        LocalDate finMois = today;

        LocalDate debutMoisPrecedent = debutMois.minusMonths(1);
        LocalDate finMoisPrecedent = debutMois.minusDays(1);

        // --- Opérations mois courant ---
        List<OperationFinanciere> opsMois = sansHorsResultat(operationRepository.findByCriteres(
                new OperationFinanciereFiltres(null, debutMois, finMois, null, null, null, null, null, null)));
        List<OperationFinanciere> revenusMois = opsMois.stream()
                .filter(o -> TypeOperation.REVENU.equals(o.getTypeOperation())).toList();
        List<OperationFinanciere> depensesMois = opsMois.stream()
                .filter(o -> TypeOperation.DEPENSE.equals(o.getTypeOperation())).toList();

        BigDecimal totalRevenusMois = revenusMois.stream()
                .map(OperationFinanciere::getMontant).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalDepensesMois = depensesMois.stream()
                .map(OperationFinanciere::getMontant).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal soldeNetMois = totalRevenusMois.subtract(totalDepensesMois);

        // --- Opérations mois précédent ---
        List<OperationFinanciere> opsPrecedent = sansHorsResultat(operationRepository.findByCriteres(
                new OperationFinanciereFiltres(null, debutMoisPrecedent, finMoisPrecedent, null, null, null, null, null, null)));
        BigDecimal totalRevenusPrecedent = opsPrecedent.stream()
                .filter(o -> TypeOperation.REVENU.equals(o.getTypeOperation()))
                .map(OperationFinanciere::getMontant).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalDepensesPrecedent = opsPrecedent.stream()
                .filter(o -> TypeOperation.DEPENSE.equals(o.getTypeOperation()))
                .map(OperationFinanciere::getMontant).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal soldeNetPrecedent = totalRevenusPrecedent.subtract(totalDepensesPrecedent);

        BigDecimal variationRevenusPct = calculerVariation(soldeNetMois, soldeNetPrecedent);
        BigDecimal variationRecettesPct = calculerVariation(totalRevenusMois, totalRevenusPrecedent);
        BigDecimal variationDepensesPct = calculerVariation(totalDepensesMois, totalDepensesPrecedent);

        // --- Chauffeurs ayant des revenus ce mois ---
        long nbChauffeursAvecRevenu = revenusMois.stream()
                .filter(o -> o.getChauffeur() != null)
                .map(o -> o.getChauffeur().getId())
                .distinct().count();

        // --- Stats flotte ---
        var allChauffeurs = chauffeurRepository.findAll();
        var allVehicules = vehiculeRepository.findAll();
        long nbChauffeursActifs = allChauffeurs.stream()
                .filter(c -> ChauffeurStatus.ACTIF.equals(c.getStatut())).count();
        long nbVehiculesEnService = allVehicules.stream()
                .filter(v -> VehiculeStatus.EN_SERVICE.equals(v.getStatut())).count();

        // --- Alertes ---
        long nbMaintenancesEnCours = maintenanceRepository.findByStatut(MaintenanceStatus.PLANIFIEE).size();
        long nbDocumentsExpires = documentRepository.findAll().stream()
                .filter(d -> DocumentStatut.EXPIRE.equals(d.getStatut())).count();

        // --- Période label ---
        String periodeLabel = "1 - " + today.getDayOfMonth() + " " +
                today.format(DateTimeFormatter.ofPattern("MMMM", Locale.FRENCH));

        // --- Dernières opérations ---
        List<OperationLigneDto> dernieres = opsMois.stream()
                .sorted(Comparator.comparing(OperationFinanciere::getDateOperation).reversed())
                .limit(5)
                .map(o -> new OperationLigneDto(
                        o.getId(),
                        o.getTypeOperation().name(),
                        o.getCommentaire(),
                        o.getChauffeur() != null ? o.getChauffeur().getFullName() : null,
                        o.getVehicule() != null ? o.getVehicule().getImmatriculation() : null,
                        TypeOperation.DEPENSE.equals(o.getTypeOperation()) ? o.getMontant().negate() : o.getMontant(),
                        o.getDateOperation()))
                .collect(Collectors.toList());

        return new DashboardSummaryResponse(
                soldeNetMois, totalRevenusMois, totalDepensesMois,
                variationRevenusPct, variationRecettesPct, variationDepensesPct,
                revenusMois.size(), (int) nbChauffeursAvecRevenu, periodeLabel,
                (int) nbChauffeursActifs, allChauffeurs.size(),
                (int) nbVehiculesEnService, allVehicules.size(),
                today,
                (int) nbMaintenancesEnCours, (int) nbDocumentsExpires,
                dernieres
        );
    }

    /**
     * Écarte les opérations de comptes de tiers (contraventions refacturées,
     * transferts) : elles mouvementent la trésorerie mais ne sont ni un
     * produit ni une charge — les compter gonflerait revenus et dépenses.
     */
    private List<OperationFinanciere> sansHorsResultat(List<OperationFinanciere> operations) {
        return operations.stream()
                .filter(o -> o.getCategorie() == null
                        || o.getCategorie().getNatureResultat() != NatureResultat.HORS_RESULTAT)
                .toList();
    }

    private BigDecimal calculerVariation(BigDecimal current, BigDecimal previous) {
        if (previous.compareTo(BigDecimal.ZERO) == 0) {
            return current.compareTo(BigDecimal.ZERO) > 0 ? BigDecimal.valueOf(100) : BigDecimal.ZERO;
        }
        return current.subtract(previous)
                .divide(previous.abs(), 4, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100))
                .setScale(1, RoundingMode.HALF_UP);
    }
}
