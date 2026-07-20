package com.tmk.vtcmanager.infrastructure.config;

import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.usecases.conditionTravail.CreateConditionTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.DeleteConditionTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionTravailByIdUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionTravailImpactUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionsTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.UpdateConditionTravailUseCase;
import com.tmk.vtcmanager.application.usecases.dashboard.GetDashboardSummaryUseCase;
import com.tmk.vtcmanager.application.usecases.etatparc.GetEtatParcUseCase;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.services.AnnulationEncaissementService;
import com.tmk.vtcmanager.application.services.AnnulationMaintenanceService;
import com.tmk.vtcmanager.application.services.ConfigurationRecetteSynchronizer;
import com.tmk.vtcmanager.application.services.JoursFeriesCalculator;
import com.tmk.vtcmanager.application.services.IndisponibiliteNettoyageService;
import com.tmk.vtcmanager.application.services.IndisponibiliteSubstitutionService;
import com.tmk.vtcmanager.application.services.VehiculeStatutHistoriqueService;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeStatutHistoriqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.MarqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculePhotoRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import com.tmk.vtcmanager.application.usecases.auth.*;
import com.tmk.vtcmanager.application.usecases.admin.*;
import com.tmk.vtcmanager.application.usecases.chauffeur.*;
import com.tmk.vtcmanager.application.usecases.configurationRecette.CreateConfigurationRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.configurationRecette.GetConfigurationRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.configurationRecette.UpdateConfigurationRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.*;
import com.tmk.vtcmanager.application.usecases.indisponibilite.*;
import com.tmk.vtcmanager.application.usecases.jourFerie.*;
import com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule.*;
import com.tmk.vtcmanager.application.usecases.maintenance.*;
import com.tmk.vtcmanager.application.usecases.programmeTravail.CreateProgrammeTravailUseCase;
import com.tmk.vtcmanager.application.usecases.programmeTravail.GetProgrammeTravailUseCase;
import com.tmk.vtcmanager.application.usecases.programmeTravail.InvertProgrammeTravailUseCase;
import com.tmk.vtcmanager.application.usecases.programmeTravail.UpdateProgrammeTravailUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.*;
import com.tmk.vtcmanager.application.usecases.vehicule.DeleteVehiculePhotoUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.UploadVehiculePhotoUseCase;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAuthPort;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.ports.auth.OtpDeliveryPort;
import com.tmk.vtcmanager.application.ports.auth.OtpHashPort;
import com.tmk.vtcmanager.application.ports.persistence.OtpCodeRepository;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import com.tmk.vtcmanager.application.ports.persistence.TransfertTresorerieRepository;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.usecases.arrete.AnnulerArreteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.ArreterCompteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.CalculerCompteCourantUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.GetArreteDecompteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.GetArreteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.GetCompteCourantUseCase;
import com.tmk.vtcmanager.application.usecases.finance.CloturerPeriodeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.ExportComptableUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetBalanceAgeeParVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetBalanceAgeeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetBilanUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetCloturesPeriodeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetCompteResultatUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetCreancesChauffeurUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetCreancesVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetMargesParVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetRapportFinancierUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetMontantAReverserEtatUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.CloturerCaisseUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.CreateCompteTresorerieUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.CreateTransfertUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.GetCloturesCaisseUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.GetComptesTresorerieUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.GetTransfertsUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.UpdateCompteTresorerieUseCase;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.*;
import com.tmk.vtcmanager.application.usecases.categorieOperation.*;
import com.tmk.vtcmanager.application.usecases.cotisation.*;
import com.tmk.vtcmanager.application.usecases.operationFinanciere.*;
import com.tmk.vtcmanager.application.usecases.penalite.*;
import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtractorPort;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversementExtractorPort;
import com.tmk.vtcmanager.application.usecases.recette.*;
import com.tmk.vtcmanager.application.usecases.payment.*;
import com.tmk.vtcmanager.application.ports.payment.PaymentGatewayPort;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import org.springframework.beans.factory.annotation.Value;
import com.tmk.vtcmanager.application.usecases.sousCategorieOperation.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class UseCaseBeanConfiguration {

    // ----- Vehicule -----
    @Bean
    public VehiculeStatutHistoriqueService vehiculeStatutHistoriqueService(
            VehiculeStatutHistoriqueRepository historiqueRepository) {
        return new VehiculeStatutHistoriqueService(historiqueRepository);
    }

    @Bean
    public CreateVehiculeUseCase createVehiculeUseCase(
            VehiculeRepository repo,
            MarqueRepository marqueRepository,
            ModeleRepository modeleRepository,
            TypeVehiculeRepository typeVehiculeRepository,
            TypeActiviteRepository typeActiviteRepository,
            GroupeVehiculeRepository groupeVehiculeRepository,
            VehiculeStatutHistoriqueService vehiculeStatutHistoriqueService) {
        return new CreateVehiculeUseCase(repo, marqueRepository, modeleRepository,
                typeVehiculeRepository, typeActiviteRepository, groupeVehiculeRepository,
                vehiculeStatutHistoriqueService);
    }

    @Bean
    public ConfigurationRecetteSynchronizer configurationRecetteSynchronizer(
            ConfigurationRecetteRepository configurationRecetteRepository) {
        return new ConfigurationRecetteSynchronizer(configurationRecetteRepository);
    }

    @Bean
    public UpdateVehiculeUseCase updateVehiculeUseCase(
            VehiculeRepository repo,
            TypeActiviteRepository typeActiviteRepository,
            GroupeVehiculeRepository groupeVehiculeRepository,
            ConditionTravailRepository conditionTravailRepository,
            ProgrammeTravailRepository programmeTravailRepository,
            ConfigurationRecetteSynchronizer configurationRecetteSynchronizer,
            VehiculeStatutHistoriqueService vehiculeStatutHistoriqueService) {
        return new UpdateVehiculeUseCase(repo, typeActiviteRepository, groupeVehiculeRepository,
                conditionTravailRepository, programmeTravailRepository, configurationRecetteSynchronizer,
                vehiculeStatutHistoriqueService);
    }

    @Bean
    public DeleteVehiculeUseCase deleteVehiculeUseCase(VehiculeRepository repo) {
        return new DeleteVehiculeUseCase(repo);
    }

    @Bean
    public RecomputeVehiculeStatusUseCase recomputeVehiculeStatusUseCase(
            VehiculeRepository vehiculeRepository,
            ChauffeurRepository chauffeurRepository,
            MaintenanceRepository maintenanceRepository,
            LignePenaliteRepository lignePenaliteRepository,
            IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository,
            VehiculeStatutHistoriqueService vehiculeStatutHistoriqueService) {
        return new RecomputeVehiculeStatusUseCase(vehiculeRepository, chauffeurRepository,
                maintenanceRepository, lignePenaliteRepository, indisponibiliteVehiculeRepository,
                vehiculeStatutHistoriqueService);
    }

    @Bean
    public GetVehiculeByIdUseCase getVehiculeByIdUseCase(
            VehiculeRepository repo,
            VehiculePhotoRepository photoRepository,
            FileStoragePort fileStoragePort) {
        return new GetVehiculeByIdUseCase(repo, photoRepository, fileStoragePort);
    }

    @Bean
    public GetAllVehiculesUseCase getAllVehiculesUseCase(
            VehiculeRepository repo,
            VehiculePhotoRepository photoRepository,
            FileStoragePort fileStoragePort) {
        return new GetAllVehiculesUseCase(repo, photoRepository, fileStoragePort);
    }

    @Bean
    public CreateVidangeUseCase createVidangeUseCase(
            VidangeRepository vidangeRepository,
            VehiculeRepository vehiculeRepository) {
        return new CreateVidangeUseCase(vidangeRepository, vehiculeRepository);
    }

    @Bean
    public GetVidangesByVehiculeUseCase getVidangesByVehiculeUseCase(
            VidangeRepository vidangeRepository) {
        return new GetVidangesByVehiculeUseCase(vidangeRepository);
    }

    @Bean
    public UploadVehiculePhotoUseCase uploadVehiculePhotoUseCase(
            VehiculeRepository vehiculeRepository,
            VehiculePhotoRepository photoRepository,
            FileStoragePort fileStoragePort) {
        return new UploadVehiculePhotoUseCase(vehiculeRepository, photoRepository, fileStoragePort);
    }

    @Bean
    public DeleteVehiculePhotoUseCase deleteVehiculePhotoUseCase(
            VehiculePhotoRepository photoRepository,
            FileStoragePort fileStoragePort) {
        return new DeleteVehiculePhotoUseCase(photoRepository, fileStoragePort);
    }

    @Bean
    public GetProgrammeTravailUseCase getProgrammeTravailUseCase(
            ProgrammeTravailRepository programmeRepository,
            VehiculeRepository vehiculeRepository) {
        return new GetProgrammeTravailUseCase(programmeRepository, vehiculeRepository);
    }

    @Bean
    public CreateProgrammeTravailUseCase createProgrammeTravailUseCase(
            ProgrammeTravailRepository programmeRepository,
            VehiculeRepository vehiculeRepository,
            ChauffeurRepository chauffeurRepository,
            IndisponibiliteNettoyageService indisponibiliteNettoyageService,
            DocumentRepository documentRepository,
            VehiculeStatutEventPublisher statutEventPublisher,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new CreateProgrammeTravailUseCase(programmeRepository, vehiculeRepository,
                chauffeurRepository, indisponibiliteNettoyageService, documentRepository,
                statutEventPublisher, chauffeurStatutEventPublisher);
    }

    @Bean
    public IndisponibiliteNettoyageService indisponibiliteNettoyageService(
            IndisponibiliteRepository indisponibiliteRepository,
            ProgrammeTravailRepository programmeTravailRepository) {
        return new IndisponibiliteNettoyageService(
                indisponibiliteRepository, programmeTravailRepository);
    }

    @Bean
    public UpdateProgrammeTravailUseCase updateProgrammeTravailUseCase(
            ProgrammeTravailRepository programmeRepository,
            VehiculeRepository vehiculeRepository,
            ChauffeurRepository chauffeurRepository,
            IndisponibiliteNettoyageService indisponibiliteNettoyageService,
            DocumentRepository documentRepository,
            VehiculeStatutEventPublisher statutEventPublisher,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new UpdateProgrammeTravailUseCase(programmeRepository, vehiculeRepository,
                chauffeurRepository, indisponibiliteNettoyageService, documentRepository,
                statutEventPublisher, chauffeurStatutEventPublisher);
    }

    @Bean
    public InvertProgrammeTravailUseCase invertProgrammeTravailUseCase(
            ProgrammeTravailRepository programmeRepository,
            VehiculeRepository vehiculeRepository) {
        return new InvertProgrammeTravailUseCase(programmeRepository, vehiculeRepository);
    }

    @Bean
    public GetConfigurationRecetteUseCase getConfigurationRecetteUseCase(
            ConfigurationRecetteRepository configurationRecetteRepository,
            VehiculeRepository vehiculeRepository) {
        return new GetConfigurationRecetteUseCase(configurationRecetteRepository, vehiculeRepository);
    }

    @Bean
    public CreateConfigurationRecetteUseCase createConfigurationRecetteUseCase(
            ConfigurationRecetteRepository configurationRecetteRepository,
            VehiculeRepository vehiculeRepository) {
        return new CreateConfigurationRecetteUseCase(configurationRecetteRepository, vehiculeRepository);
    }

    @Bean
    public UpdateConfigurationRecetteUseCase updateConfigurationRecetteUseCase(
            ConfigurationRecetteRepository configurationRecetteRepository,
            VehiculeRepository vehiculeRepository) {
        return new UpdateConfigurationRecetteUseCase(configurationRecetteRepository, vehiculeRepository);
    }

    // ----- Chauffeur -----
    @Bean
    public SyncChauffeurAccountUseCase syncChauffeurAccountUseCase(
            KeycloakAdminPort adminPort,
            ProvisionChauffeurAccountUseCase provisionChauffeurAccountUseCase) {
        return new SyncChauffeurAccountUseCase(adminPort, provisionChauffeurAccountUseCase);
    }

    @Bean
    public CreateChauffeurUseCase createChauffeurUseCase(
            ChauffeurRepository repo,
            TypeDocumentRepository typeDocumentRepository,
            DocumentRepository documentRepository,
            FileStoragePort fileStoragePort,
            SyncChauffeurAccountUseCase syncChauffeurAccountUseCase) {
        return new CreateChauffeurUseCase(repo, typeDocumentRepository, documentRepository,
                fileStoragePort, syncChauffeurAccountUseCase);
    }

    @Bean
    public UpdateChauffeurUseCase updateChauffeurUseCase(
            ChauffeurRepository repo,
            DocumentRepository documentRepository,
            TypeDocumentRepository typeDocumentRepository,
            FileStoragePort fileStoragePort,
            SyncChauffeurAccountUseCase syncChauffeurAccountUseCase) {
        return new UpdateChauffeurUseCase(repo, documentRepository, typeDocumentRepository,
                fileStoragePort, syncChauffeurAccountUseCase);
    }

    @Bean
    public DeleteChauffeurUseCase deleteChauffeurUseCase(ChauffeurRepository repo) {
        return new DeleteChauffeurUseCase(repo);
    }

    @Bean
    public GetChauffeurByIdUseCase getChauffeurByIdUseCase(
            ChauffeurRepository repo,
            ProgrammeTravailRepository programmeTravailRepository,
            FileStoragePort fileStoragePort) {
        return new GetChauffeurByIdUseCase(repo, programmeTravailRepository, fileStoragePort);
    }

    @Bean
    public GetAllChauffeursUseCase getAllChauffeursUseCase(ChauffeurRepository repo,
                                                           FileStoragePort fileStoragePort) {
        return new GetAllChauffeursUseCase(repo, fileStoragePort);
    }

    @Bean
    public AssignVehiculeToChauffeurUseCase assignVehiculeToChauffeurUseCase(
            ChauffeurRepository chauffeurRepo, VehiculeRepository vehiculeRepo,
            VehiculeStatutEventPublisher statutEventPublisher,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new AssignVehiculeToChauffeurUseCase(chauffeurRepo, vehiculeRepo,
                statutEventPublisher, chauffeurStatutEventPublisher);
    }

    @Bean
    public UnassignVehiculeFromChauffeurUseCase unassignVehiculeFromChauffeurUseCase(
            ChauffeurRepository chauffeurRepo,
            VehiculeRepository vehiculeRepo,
            ProgrammeTravailRepository programmeTravailRepository,
            IndisponibiliteNettoyageService indisponibiliteNettoyageService,
            VehiculeStatutEventPublisher statutEventPublisher,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new UnassignVehiculeFromChauffeurUseCase(chauffeurRepo, vehiculeRepo,
                programmeTravailRepository, indisponibiliteNettoyageService,
                statutEventPublisher, chauffeurStatutEventPublisher);
    }

    // ----- Contravention -----
    @Bean
    public CreateContraventionUseCase createContraventionUseCase(ContraventionRepository repo) {
        return new CreateContraventionUseCase(repo);
    }

    @Bean
    public UpdateContraventionUseCase updateContraventionUseCase(ContraventionRepository repo) {
        return new UpdateContraventionUseCase(repo);
    }

    @Bean
    public DeleteContraventionUseCase deleteContraventionUseCase(ContraventionRepository repo) {
        return new DeleteContraventionUseCase(repo);
    }

    @Bean
    public GetContraventionByIdUseCase getContraventionByIdUseCase(ContraventionRepository repo) {
        return new GetContraventionByIdUseCase(repo);
    }

    @Bean
    public GetAllContraventionsUseCase getAllContraventionsUseCase(ContraventionRepository repo) {
        return new GetAllContraventionsUseCase(repo);
    }

    @Bean
    public PayContraventionUseCase payContraventionUseCase(
            ContraventionRepository repo,
            OperationFinanciereRepository operationFinanciereRepository,
            CategorieOperationRepository categorieOperationRepository,
            CompteTresorerieResolver compteTresorerieResolver) {
        return new PayContraventionUseCase(repo, operationFinanciereRepository,
                categorieOperationRepository, compteTresorerieResolver);
    }

    @Bean
    public ReverseContraventionUseCase reverseContraventionUseCase(
            ContraventionRepository repo,
            OperationFinanciereRepository operationFinanciereRepository,
            CategorieOperationRepository categorieOperationRepository,
            CompteTresorerieResolver compteTresorerieResolver) {
        return new ReverseContraventionUseCase(repo, operationFinanciereRepository,
                categorieOperationRepository, compteTresorerieResolver);
    }

    // ----- Maintenance -----
    @Bean
    public ScheduleMaintenanceUseCase scheduleMaintenanceUseCase(
            MaintenanceRepository maintenanceRepo,
            VehiculeRepository vehiculeRepo,
            CategorieOperationRepository categorieOperationRepository,
            VehiculeStatutEventPublisher statutEventPublisher,
            CompleteMaintenanceUseCase completeMaintenanceUseCase) {
        return new ScheduleMaintenanceUseCase(maintenanceRepo, vehiculeRepo,
                categorieOperationRepository, statutEventPublisher, completeMaintenanceUseCase);
    }

    @Bean
    public PlanifierVidangesDuesUseCase planifierVidangesDuesUseCase(
            VidangeRepository vidangeRepository,
            MaintenanceRepository maintenanceRepository,
            ScheduleMaintenanceUseCase scheduleMaintenanceUseCase) {
        return new PlanifierVidangesDuesUseCase(
                vidangeRepository, maintenanceRepository, scheduleMaintenanceUseCase);
    }

    @Bean
    public UpdateMaintenanceUseCase updateMaintenanceUseCase(
            MaintenanceRepository repo,
            CategorieOperationRepository categorieOperationRepository,
            VehiculeStatutEventPublisher statutEventPublisher) {
        return new UpdateMaintenanceUseCase(repo, categorieOperationRepository, statutEventPublisher);
    }

    @Bean
    public DeleteMaintenanceUseCase deleteMaintenanceUseCase(
            MaintenanceRepository repo,
            VehiculeStatutEventPublisher statutEventPublisher) {
        return new DeleteMaintenanceUseCase(repo, statutEventPublisher);
    }

    @Bean
    public AnnulerMaintenanceUseCase annulerMaintenanceUseCase(
            MaintenanceRepository repo,
            VehiculeStatutEventPublisher statutEventPublisher) {
        return new AnnulerMaintenanceUseCase(repo, statutEventPublisher);
    }

    @Bean
    public GetMaintenanceByIdUseCase getMaintenanceByIdUseCase(MaintenanceRepository repo) {
        return new GetMaintenanceByIdUseCase(repo);
    }

    @Bean
    public GetAllMaintenancesUseCase getAllMaintenancesUseCase(MaintenanceRepository repo) {
        return new GetAllMaintenancesUseCase(repo);
    }

    @Bean
    public CompleteMaintenanceUseCase completeMaintenanceUseCase(
            MaintenanceRepository repo,
            OperationFinanciereRepository operationRepository,
            CategorieOperationRepository categorieOperationRepository,
            SousCategorieOperationRepository sousCategorieOperationRepository,
            VehiculeStatutEventPublisher statutEventPublisher,
            CompteTresorerieResolver compteTresorerieResolver,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new CompleteMaintenanceUseCase(repo, operationRepository,
                categorieOperationRepository, sousCategorieOperationRepository, statutEventPublisher,
                compteTresorerieResolver, periodeClotureeGuard);
    }

    @Bean
    public GetUpcomingMaintenancesUseCase getUpcomingMaintenancesUseCase(MaintenanceRepository repo) {
        return new GetUpcomingMaintenancesUseCase(repo);
    }

    @Bean
    public GetMaintenanceTotalCostByVehiculeUseCase getMaintenanceTotalCostByVehiculeUseCase(MaintenanceRepository repo) {
        return new GetMaintenanceTotalCostByVehiculeUseCase(repo);
    }

    // ----- Dashboard -----
    @Bean
    public GetDashboardSummaryUseCase getDashboardSummaryUseCase(
            OperationFinanciereRepository operationRepository,
            VehiculeRepository vehiculeRepository,
            ChauffeurRepository chauffeurRepository,
            MaintenanceRepository maintenanceRepository,
            DocumentRepository documentRepository) {
        return new GetDashboardSummaryUseCase(operationRepository,
                vehiculeRepository, chauffeurRepository, maintenanceRepository, documentRepository);
    }

    // ----- État de parc -----
    @Bean
    public GetEtatParcUseCase getEtatParcUseCase(
            VehiculeRepository vehiculeRepository,
            VehiculeStatutHistoriqueRepository vehiculeStatutHistoriqueRepository,
            DocumentRepository documentRepository,
            IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository,
            VidangeRepository vidangeRepository,
            MaintenanceRepository maintenanceRepository) {
        return new GetEtatParcUseCase(vehiculeRepository,
                vehiculeStatutHistoriqueRepository, documentRepository,
                indisponibiliteVehiculeRepository, vidangeRepository,
                maintenanceRepository);
    }

    // ----- ConditionTravail -----
    @Bean
    public GetConditionsTravailUseCase getConditionsTravailUseCase(ConditionTravailRepository conditionTravailRepository) {
        return new GetConditionsTravailUseCase(conditionTravailRepository);
    }

    @Bean
    public GetConditionTravailByIdUseCase getConditionTravailByIdUseCase(ConditionTravailRepository conditionTravailRepository) {
        return new GetConditionTravailByIdUseCase(conditionTravailRepository);
    }

    @Bean
    public CreateConditionTravailUseCase createConditionTravailUseCase(ConditionTravailRepository conditionTravailRepository) {
        return new CreateConditionTravailUseCase(conditionTravailRepository);
    }

    @Bean
    public GetConditionTravailImpactUseCase getConditionTravailImpactUseCase(
            VehiculeRepository vehiculeRepository,
            ProgrammeTravailRepository programmeTravailRepository,
            IndisponibiliteRepository indisponibiliteRepository) {
        return new GetConditionTravailImpactUseCase(
                vehiculeRepository, programmeTravailRepository, indisponibiliteRepository);
    }

    @Bean
    public UpdateConditionTravailUseCase updateConditionTravailUseCase(
            ConditionTravailRepository conditionTravailRepository,
            VehiculeRepository vehiculeRepository,
            ProgrammeTravailRepository programmeTravailRepository,
            ChauffeurRepository chauffeurRepository,
            ConfigurationRecetteSynchronizer configurationRecetteSynchronizer,
            IndisponibiliteNettoyageService indisponibiliteNettoyageService,
            VehiculeStatutEventPublisher statutEventPublisher,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new UpdateConditionTravailUseCase(
                conditionTravailRepository, vehiculeRepository,
                programmeTravailRepository, chauffeurRepository,
                configurationRecetteSynchronizer, indisponibiliteNettoyageService,
                statutEventPublisher, chauffeurStatutEventPublisher);
    }

    @Bean
    public DeleteConditionTravailUseCase deleteConditionTravailUseCase(ConditionTravailRepository conditionTravailRepository) {
        return new DeleteConditionTravailUseCase(conditionTravailRepository);
    }

    // ----- CatalogueElementMaintenance -----
    @Bean
    public GetAllCatalogueElementsMaintenanceUseCase getAllCatalogueElementsMaintenanceUseCase(CatalogueElementMaintenanceRepository repo) {
        return new GetAllCatalogueElementsMaintenanceUseCase(repo);
    }

    @Bean
    public GetActifsCatalogueElementsMaintenanceUseCase getActifsCatalogueElementsMaintenanceUseCase(CatalogueElementMaintenanceRepository repo) {
        return new GetActifsCatalogueElementsMaintenanceUseCase(repo);
    }

    @Bean
    public CreateCatalogueElementMaintenanceUseCase createCatalogueElementMaintenanceUseCase(CatalogueElementMaintenanceRepository repo) {
        return new CreateCatalogueElementMaintenanceUseCase(repo);
    }

    @Bean
    public DeleteCatalogueElementMaintenanceUseCase deleteCatalogueElementMaintenanceUseCase(
            CatalogueElementMaintenanceRepository repo, FileStoragePort storage) {
        return new DeleteCatalogueElementMaintenanceUseCase(repo, storage);
    }

    @Bean
    public UpdateCatalogueElementMaintenanceUseCase updateCatalogueElementMaintenanceUseCase(
            CatalogueElementMaintenanceRepository repo, FileStoragePort storage) {
        return new UpdateCatalogueElementMaintenanceUseCase(repo, storage);
    }

    @Bean
    public ToggleActifCatalogueElementMaintenanceUseCase toggleActifCatalogueElementMaintenanceUseCase(CatalogueElementMaintenanceRepository repo) {
        return new ToggleActifCatalogueElementMaintenanceUseCase(repo);
    }

    // ----- CategorieOperation -----
    @Bean
    public CreateCategorieOperationUseCase createCategorieOperationUseCase(CategorieOperationRepository repo) {
        return new CreateCategorieOperationUseCase(repo);
    }

    @Bean
    public UpdateCategorieOperationUseCase updateCategorieOperationUseCase(CategorieOperationRepository repo) {
        return new UpdateCategorieOperationUseCase(repo);
    }

    @Bean
    public DeleteCategorieOperationUseCase deleteCategorieOperationUseCase(CategorieOperationRepository repo) {
        return new DeleteCategorieOperationUseCase(repo);
    }

    @Bean
    public GetCategorieOperationByIdUseCase getCategorieOperationByIdUseCase(
            CategorieOperationRepository repo,
            SousCategorieOperationRepository sousCategorieRepo) {
        return new GetCategorieOperationByIdUseCase(repo, sousCategorieRepo);
    }

    @Bean
    public GetAllCategoriesOperationUseCase getAllCategoriesOperationUseCase(
            CategorieOperationRepository repo,
            SousCategorieOperationRepository sousCategorieRepo) {
        return new GetAllCategoriesOperationUseCase(repo, sousCategorieRepo);
    }

    @Bean
    public GetCategorieOperationBySousCategorieUseCase getCategorieOperationBySousCategorieUseCase(
            CategorieOperationRepository repo,
            SousCategorieOperationRepository sousCategorieRepo) {
        return new GetCategorieOperationBySousCategorieUseCase(repo, sousCategorieRepo);
    }

    // ----- SousCategorieOperation -----
    @Bean
    public CreateSousCategorieOperationUseCase createSousCategorieOperationUseCase(SousCategorieOperationRepository repo) {
        return new CreateSousCategorieOperationUseCase(repo);
    }

    @Bean
    public UpdateSousCategorieOperationUseCase updateSousCategorieOperationUseCase(SousCategorieOperationRepository repo) {
        return new UpdateSousCategorieOperationUseCase(repo);
    }

    @Bean
    public DeleteSousCategorieOperationUseCase deleteSousCategorieOperationUseCase(SousCategorieOperationRepository repo) {
        return new DeleteSousCategorieOperationUseCase(repo);
    }

    @Bean
    public GetAllSousCategoriesOperationUseCase getAllSousCategoriesOperationUseCase(SousCategorieOperationRepository repo) {
        return new GetAllSousCategoriesOperationUseCase(repo);
    }

    // ----- Cotisation -----
    @Bean
    public GenererLignesCotisationUseCase genererLignesCotisationUseCase(
            ProgrammeTravailRepository programmeTravailRepository,
            ConfigurationRecetteRepository configurationRecetteRepository,
            LigneCotisationRepository ligneCotisationRepository,
            IndisponibiliteSubstitutionService indisponibiliteSubstitutionService,
            IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository,
            JourFerieRepository jourFerieRepository) {
        return new GenererLignesCotisationUseCase(programmeTravailRepository, configurationRecetteRepository,
                ligneCotisationRepository, indisponibiliteSubstitutionService, indisponibiliteVehiculeRepository,
                jourFerieRepository);
    }

    @Bean
    public GetLignesCotisationUseCase getLignesCotisationUseCase(LigneCotisationRepository ligneCotisationRepository) {
        return new GetLignesCotisationUseCase(ligneCotisationRepository);
    }

    @Bean
    public CreateEncaissementCotisationUseCase createEncaissementCotisationUseCase(
            LigneCotisationRepository ligneCotisationRepository,
            EncaissementCotisationRepository encaissementCotisationRepository,
            OperationFinanciereRepository operationFinanciereRepository,
            CategorieOperationRepository categorieOperationRepository,
            CompteTresorerieResolver compteTresorerieResolver,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new CreateEncaissementCotisationUseCase(
                ligneCotisationRepository, encaissementCotisationRepository,
                operationFinanciereRepository, categorieOperationRepository,
                compteTresorerieResolver, periodeClotureeGuard);
    }

    @Bean
    public AnnulerLigneCotisationUseCase annulerLigneCotisationUseCase(LigneCotisationRepository ligneCotisationRepository) {
        return new AnnulerLigneCotisationUseCase(ligneCotisationRepository);
    }

    // ----- Recette -----
    @Bean
    public GenererLignesRecetteUseCase genererLignesRecetteUseCase(
            ProgrammeTravailRepository programmeTravailRepository,
            ConfigurationRecetteRepository configurationRecetteRepository,
            LigneRecetteRepository ligneRecetteRepository,
            IndisponibiliteSubstitutionService indisponibiliteSubstitutionService,
            IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository,
            JourFerieRepository jourFerieRepository) {
        return new GenererLignesRecetteUseCase(programmeTravailRepository, configurationRecetteRepository,
                ligneRecetteRepository, indisponibiliteSubstitutionService, indisponibiliteVehiculeRepository,
                jourFerieRepository);
    }

    @Bean
    public GetLignesRecetteUseCase getLignesRecetteUseCase(LigneRecetteRepository ligneRecetteRepository) {
        return new GetLignesRecetteUseCase(ligneRecetteRepository);
    }

    @Bean
    public CreateEncaissementUseCase createEncaissementUseCase(
            LigneRecetteRepository ligneRecetteRepository,
            EncaissementRepository encaissementRepository,
            ConfigurationRecetteRepository configurationRecetteRepository,
            OperationFinanciereRepository operationFinanciereRepository,
            CategorieOperationRepository categorieOperationRepository,
            CompteTresorerieResolver compteTresorerieResolver,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new CreateEncaissementUseCase(
                ligneRecetteRepository, encaissementRepository,
                configurationRecetteRepository, operationFinanciereRepository,
                categorieOperationRepository, compteTresorerieResolver, periodeClotureeGuard);
    }

    @Bean
    public ConfirmerVersementUseCase confirmerVersementUseCase(LigneRecetteRepository ligneRecetteRepository) {
        return new ConfirmerVersementUseCase(ligneRecetteRepository);
    }

    @Bean
    public AnnulerLigneRecetteUseCase annulerLigneRecetteUseCase(LigneRecetteRepository ligneRecetteRepository) {
        return new AnnulerLigneRecetteUseCase(ligneRecetteRepository);
    }

    // ----- OperationFinanciere -----
    @Bean
    public CreateOperationFinanciereUseCase createOperationFinanciereUseCase(
            OperationFinanciereRepository repo,
            ChauffeurRepository chauffeurRepository,
            VehiculeRepository vehiculeRepository,
            LigneRecetteRepository ligneRecetteRepository,
            LigneCotisationRepository ligneCotisationRepository,
            LignePenaliteRepository lignePenaliteRepository,
            SousCategorieOperationRepository sousCategorieOperationRepository,
            CompteTresorerieResolver compteTresorerieResolver,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new CreateOperationFinanciereUseCase(repo, chauffeurRepository, vehiculeRepository,
                ligneRecetteRepository, ligneCotisationRepository, lignePenaliteRepository,
                sousCategorieOperationRepository, compteTresorerieResolver, periodeClotureeGuard);
    }

    @Bean
    public UpdateOperationFinanciereUseCase updateOperationFinanciereUseCase(OperationFinanciereRepository repo) {
        return new UpdateOperationFinanciereUseCase(repo);
    }

    @Bean
    public GetOperationFinanciereByIdUseCase getOperationFinanciereByIdUseCase(OperationFinanciereRepository repo) {
        return new GetOperationFinanciereByIdUseCase(repo);
    }

    @Bean
    public GetAllOperationsFinancieresUseCase getAllOperationsFinancieresUseCase(OperationFinanciereRepository repo) {
        return new GetAllOperationsFinancieresUseCase(repo);
    }

    @Bean
    public CalculerSoldeOperationsFinancieresUseCase calculerSoldeOperationsFinancieresUseCase(
            OperationFinanciereRepository repo) {
        return new CalculerSoldeOperationsFinancieresUseCase(repo);
    }

    @Bean
    public AnnulationEncaissementService annulationEncaissementService(
            EncaissementRepository encaissementRepository,
            EncaissementCotisationRepository encaissementCotisationRepository,
            EncaissementPenaliteRepository encaissementPenaliteRepository,
            LigneRecetteRepository ligneRecetteRepository,
            LigneCotisationRepository ligneCotisationRepository,
            LignePenaliteRepository lignePenaliteRepository) {
        return new AnnulationEncaissementService(
                encaissementRepository, encaissementCotisationRepository, encaissementPenaliteRepository,
                ligneRecetteRepository, ligneCotisationRepository, lignePenaliteRepository);
    }

    @Bean
    public AnnulationMaintenanceService annulationMaintenanceService(
            MaintenanceRepository maintenanceRepository,
            VehiculeStatutEventPublisher statutEventPublisher) {
        return new AnnulationMaintenanceService(maintenanceRepository, statutEventPublisher);
    }

    @Bean
    public AnnulerOperationFinanciereUseCase annulerOperationFinanciereUseCase(
            OperationFinanciereRepository repo,
            AnnulationEncaissementService annulationEncaissementService,
            AnnulationMaintenanceService annulationMaintenanceService,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new AnnulerOperationFinanciereUseCase(
                repo, annulationEncaissementService, annulationMaintenanceService,
                periodeClotureeGuard);
    }

    // ----- Penalite -----
    @Bean
    public GetLignesPenaliteUseCase getLignesPenaliteUseCase(LignePenaliteRepository lignePenaliteRepository) {
        return new GetLignesPenaliteUseCase(lignePenaliteRepository);
    }

    @Bean
    public CreateLignePenaliteUseCase createLignePenaliteUseCase(
            LignePenaliteRepository lignePenaliteRepository,
            VehiculeRepository vehiculeRepository,
            ChauffeurRepository chauffeurRepository,
            ConditionTravailRepository conditionTravailRepository) {
        return new CreateLignePenaliteUseCase(lignePenaliteRepository, vehiculeRepository,
                chauffeurRepository, conditionTravailRepository);
    }

    @Bean
    public GenererLignesPenaliteUseCase genererLignesPenaliteUseCase(
            ProgrammeTravailRepository programmeTravailRepository,
            ConditionTravailRepository conditionTravailRepository,
            LigneRecetteRepository ligneRecetteRepository,
            LignePenaliteRepository lignePenaliteRepository,
            IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository) {
        return new GenererLignesPenaliteUseCase(
                programmeTravailRepository, conditionTravailRepository,
                ligneRecetteRepository, lignePenaliteRepository, indisponibiliteVehiculeRepository);
    }

    @Bean
    public CreateEncaissementPenaliteUseCase createEncaissementPenaliteUseCase(
            LignePenaliteRepository lignePenaliteRepository,
            EncaissementPenaliteRepository encaissementPenaliteRepository,
            OperationFinanciereRepository operationFinanciereRepository,
            CategorieOperationRepository categorieOperationRepository,
            CompteTresorerieResolver compteTresorerieResolver,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new CreateEncaissementPenaliteUseCase(
                lignePenaliteRepository, encaissementPenaliteRepository,
                operationFinanciereRepository, categorieOperationRepository,
                compteTresorerieResolver, periodeClotureeGuard);
    }

    @Bean
    public ExecuterBuzzerUseCase executerBuzzerUseCase(LignePenaliteRepository lignePenaliteRepository) {
        return new ExecuterBuzzerUseCase(lignePenaliteRepository);
    }

    @Bean
    public NotifierAvertissementUseCase notifierAvertissementUseCase(LignePenaliteRepository lignePenaliteRepository) {
        return new NotifierAvertissementUseCase(lignePenaliteRepository);
    }

    @Bean
    public DemarrerImmobilisationUseCase demarrerImmobilisationUseCase(
            LignePenaliteRepository lignePenaliteRepository,
            VehiculeStatutEventPublisher statutEventPublisher) {
        return new DemarrerImmobilisationUseCase(lignePenaliteRepository, statutEventPublisher);
    }

    @Bean
    public LeverImmobilisationUseCase leverImmobilisationUseCase(
            LignePenaliteRepository lignePenaliteRepository,
            VehiculeStatutEventPublisher statutEventPublisher) {
        return new LeverImmobilisationUseCase(lignePenaliteRepository, statutEventPublisher);
    }

    @Bean
    public AnnulerLignePenaliteUseCase annulerLignePenaliteUseCase(LignePenaliteRepository lignePenaliteRepository) {
        return new AnnulerLignePenaliteUseCase(lignePenaliteRepository);
    }

    // ----- Import PDF des contraventions de l'État -----
    @Bean
    public ImporterContraventionsUseCase importerContraventionsUseCase(
            ContraventionExtractorPort contraventionExtractorPort,
            VehiculeRepository vehiculeRepository,
            ChauffeurRepository chauffeurRepository,
            ProgrammeTravailRepository programmeTravailRepository,
            ContraventionRepository contraventionRepository,
            FileStoragePort fileStoragePort) {
        return new ImporterContraventionsUseCase(contraventionExtractorPort, vehiculeRepository,
                chauffeurRepository, programmeTravailRepository, contraventionRepository, fileStoragePort);
    }

    @Bean
    public ConfirmerImportContraventionsUseCase confirmerImportContraventionsUseCase(
            ContraventionRepository contraventionRepository) {
        return new ConfirmerImportContraventionsUseCase(contraventionRepository);
    }

    // ----- Reversement par quittance de l'État -----
    @Bean
    public PreviewReversementQuittanceUseCase previewReversementQuittanceUseCase(
            QuittanceReversementExtractorPort quittanceReversementExtractorPort,
            ContraventionRepository contraventionRepository,
            FileStoragePort fileStoragePort) {
        return new PreviewReversementQuittanceUseCase(
                quittanceReversementExtractorPort, contraventionRepository, fileStoragePort);
    }

    @Bean
    public ConfirmerReversementQuittanceUseCase confirmerReversementQuittanceUseCase(
            ContraventionRepository contraventionRepository,
            ReverseContraventionUseCase reverseContraventionUseCase) {
        return new ConfirmerReversementQuittanceUseCase(
                contraventionRepository, reverseContraventionUseCase);
    }

    // ----- Auth -----
    @Bean
    public LoginUseCase loginUseCase(KeycloakAuthPort authPort) {
        return new LoginUseCase(authPort);
    }

    @Bean
    public RegisterUseCase registerUseCase(KeycloakAdminPort adminPort) {
        return new RegisterUseCase(adminPort);
    }

    @Bean
    public ForgotPasswordUseCase forgotPasswordUseCase(KeycloakAdminPort adminPort) {
        return new ForgotPasswordUseCase(adminPort);
    }

    @Bean
    public RefreshTokenUseCase refreshTokenUseCase(KeycloakAuthPort authPort) {
        return new RefreshTokenUseCase(authPort);
    }

    @Bean
    public LogoutUseCase logoutUseCase(KeycloakAuthPort authPort) {
        return new LogoutUseCase(authPort);
    }

    // ----- Auth OTP (app chauffeur) -----
    @Bean
    public RequestOtpUseCase requestOtpUseCase(ChauffeurRepository chauffeurRepository,
                                               OtpCodeRepository otpCodeRepository,
                                               OtpHashPort otpHashPort,
                                               OtpDeliveryPort otpDeliveryPort) {
        return new RequestOtpUseCase(chauffeurRepository, otpCodeRepository, otpHashPort, otpDeliveryPort);
    }

    @Bean
    public VerifyOtpUseCase verifyOtpUseCase(ChauffeurRepository chauffeurRepository,
                                             OtpCodeRepository otpCodeRepository,
                                             OtpHashPort otpHashPort,
                                             KeycloakAuthPort authPort) {
        return new VerifyOtpUseCase(chauffeurRepository, otpCodeRepository, otpHashPort, authPort);
    }

    @Bean
    public ChauffeurPasswordLoginUseCase chauffeurPasswordLoginUseCase(
            KeycloakAuthPort authPort, ChauffeurRepository chauffeurRepository) {
        return new ChauffeurPasswordLoginUseCase(authPort, chauffeurRepository);
    }

    @Bean
    public SetChauffeurPasswordUseCase setChauffeurPasswordUseCase(
            ChauffeurRepository chauffeurRepository, KeycloakAdminPort adminPort) {
        return new SetChauffeurPasswordUseCase(chauffeurRepository, adminPort);
    }

    @Bean
    public ProvisionChauffeurAccountUseCase provisionChauffeurAccountUseCase(
            ChauffeurRepository chauffeurRepository, KeycloakAdminPort adminPort) {
        return new ProvisionChauffeurAccountUseCase(chauffeurRepository, adminPort);
    }

    // ----- Paiement Mobile Money (V2) -----
    @Bean
    public InitierPaiementUseCase initierPaiementUseCase(
            PaiementRepository paiementRepository,
            PaymentGatewayPort paymentGatewayPort,
            GetLignesRecetteUseCase getLignesRecetteUseCase,
            GetLignesCotisationUseCase getLignesCotisationUseCase,
            @Value("${app.payment.callback-base-url:http://localhost:8081}") String callbackBaseUrl,
            @Value("${app.payment.provider:simulation}") String provider) {
        String callbackUrl = callbackBaseUrl + "/api/payments/webhook/" + provider;
        return new InitierPaiementUseCase(paiementRepository, paymentGatewayPort,
                getLignesRecetteUseCase, getLignesCotisationUseCase, callbackUrl);
    }

    @Bean
    public TraiterNotificationPaiementUseCase traiterNotificationPaiementUseCase(
            PaiementRepository paiementRepository,
            PaymentGatewayPort paymentGatewayPort,
            CreateEncaissementUseCase createEncaissementUseCase,
            CreateEncaissementCotisationUseCase createEncaissementCotisationUseCase) {
        return new TraiterNotificationPaiementUseCase(paiementRepository, paymentGatewayPort,
                createEncaissementUseCase, createEncaissementCotisationUseCase);
    }

    @Bean
    public GetStatutPaiementUseCase getStatutPaiementUseCase(
            PaiementRepository paiementRepository,
            PaymentGatewayPort paymentGatewayPort,
            TraiterNotificationPaiementUseCase traiterNotificationPaiementUseCase) {
        return new GetStatutPaiementUseCase(paiementRepository, paymentGatewayPort,
                traiterNotificationPaiementUseCase);
    }

    // ----- Admin / RBAC -----
    @Bean
    public GetAllUsersUseCase getAllUsersUseCase(KeycloakAdminPort adminPort) {
        return new GetAllUsersUseCase(adminPort);
    }

    @Bean
    public GetUserByIdUseCase getUserByIdUseCase(KeycloakAdminPort adminPort) {
        return new GetUserByIdUseCase(adminPort);
    }

    @Bean
    public UpdateUserUseCase updateUserUseCase(KeycloakAdminPort adminPort) {
        return new UpdateUserUseCase(adminPort);
    }

    @Bean
    public DeleteUserUseCase deleteUserUseCase(KeycloakAdminPort adminPort) {
        return new DeleteUserUseCase(adminPort);
    }

    @Bean
    public SetUserEnabledUseCase setUserEnabledUseCase(KeycloakAdminPort adminPort) {
        return new SetUserEnabledUseCase(adminPort);
    }

    @Bean
    public GetAllRealmRolesUseCase getAllRealmRolesUseCase(KeycloakAdminPort adminPort) {
        return new GetAllRealmRolesUseCase(adminPort);
    }

    @Bean
    public AssignRoleUseCase assignRoleUseCase(KeycloakAdminPort adminPort) {
        return new AssignRoleUseCase(adminPort);
    }

    @Bean
    public RemoveRoleUseCase removeRoleUseCase(KeycloakAdminPort adminPort) {
        return new RemoveRoleUseCase(adminPort);
    }

    // ----- Indisponibilité -----
    @Bean
    public IndisponibiliteSubstitutionService indisponibiliteSubstitutionService(
            IndisponibiliteRepository repo) {
        return new IndisponibiliteSubstitutionService(repo);
    }

    @Bean
    public CreateIndisponibiliteUseCase createIndisponibiliteUseCase(
            IndisponibiliteRepository repo, ProgrammeTravailRepository programmeTravailRepository,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new CreateIndisponibiliteUseCase(repo, programmeTravailRepository, chauffeurStatutEventPublisher);
    }

    @Bean
    public UpdateIndisponibiliteUseCase updateIndisponibiliteUseCase(
            IndisponibiliteRepository repo, ProgrammeTravailRepository programmeTravailRepository,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new UpdateIndisponibiliteUseCase(repo, programmeTravailRepository, chauffeurStatutEventPublisher);
    }

    @Bean
    public DeleteIndisponibiliteUseCase deleteIndisponibiliteUseCase(
            IndisponibiliteRepository repo,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new DeleteIndisponibiliteUseCase(repo, chauffeurStatutEventPublisher);
    }

    @Bean
    public GetIndisponibiliteByIdUseCase getIndisponibiliteByIdUseCase(IndisponibiliteRepository repo) {
        return new GetIndisponibiliteByIdUseCase(repo);
    }

    @Bean
    public GetAllIndisponibilitesUseCase getAllIndisponibilitesUseCase(IndisponibiliteRepository repo) {
        return new GetAllIndisponibilitesUseCase(repo);
    }

    @Bean
    public TerminerIndisponibiliteUseCase terminerIndisponibiliteUseCase(
            IndisponibiliteRepository repo,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new TerminerIndisponibiliteUseCase(repo, chauffeurStatutEventPublisher);
    }

    @Bean
    public SynchroniserIndisponibilitesUseCase synchroniserIndisponibilitesUseCase(
            IndisponibiliteRepository repo,
            ChauffeurStatutEventPublisher chauffeurStatutEventPublisher) {
        return new SynchroniserIndisponibilitesUseCase(repo, chauffeurStatutEventPublisher);
    }

    @Bean
    public RecomputeChauffeurStatusUseCase recomputeChauffeurStatusUseCase(
            ChauffeurRepository chauffeurRepository,
            IndisponibiliteRepository indisponibiliteRepository) {
        return new RecomputeChauffeurStatusUseCase(chauffeurRepository, indisponibiliteRepository);
    }

    // ----- Indisponibilité véhicule -----
    @Bean
    public CreateIndisponibiliteVehiculeUseCase createIndisponibiliteVehiculeUseCase(
            IndisponibiliteVehiculeRepository repo,
            VehiculeStatutEventPublisher vehiculeStatutEventPublisher) {
        return new CreateIndisponibiliteVehiculeUseCase(repo, vehiculeStatutEventPublisher);
    }

    @Bean
    public UpdateIndisponibiliteVehiculeUseCase updateIndisponibiliteVehiculeUseCase(
            IndisponibiliteVehiculeRepository repo,
            VehiculeStatutEventPublisher vehiculeStatutEventPublisher) {
        return new UpdateIndisponibiliteVehiculeUseCase(repo, vehiculeStatutEventPublisher);
    }

    @Bean
    public DeleteIndisponibiliteVehiculeUseCase deleteIndisponibiliteVehiculeUseCase(
            IndisponibiliteVehiculeRepository repo,
            VehiculeStatutEventPublisher vehiculeStatutEventPublisher) {
        return new DeleteIndisponibiliteVehiculeUseCase(repo, vehiculeStatutEventPublisher);
    }

    @Bean
    public GetIndisponibiliteVehiculeByIdUseCase getIndisponibiliteVehiculeByIdUseCase(
            IndisponibiliteVehiculeRepository repo) {
        return new GetIndisponibiliteVehiculeByIdUseCase(repo);
    }

    @Bean
    public GetAllIndisponibilitesVehiculeUseCase getAllIndisponibilitesVehiculeUseCase(
            IndisponibiliteVehiculeRepository repo) {
        return new GetAllIndisponibilitesVehiculeUseCase(repo);
    }

    @Bean
    public TerminerIndisponibiliteVehiculeUseCase terminerIndisponibiliteVehiculeUseCase(
            IndisponibiliteVehiculeRepository repo,
            VehiculeStatutEventPublisher vehiculeStatutEventPublisher) {
        return new TerminerIndisponibiliteVehiculeUseCase(repo, vehiculeStatutEventPublisher);
    }

    @Bean
    public SynchroniserIndisponibilitesVehiculeUseCase synchroniserIndisponibilitesVehiculeUseCase(
            IndisponibiliteVehiculeRepository repo,
            VehiculeStatutEventPublisher vehiculeStatutEventPublisher) {
        return new SynchroniserIndisponibilitesVehiculeUseCase(repo, vehiculeStatutEventPublisher);
    }

    // ----- Trésorerie -----
    @Bean
    public CompteTresorerieResolver compteTresorerieResolver(CompteTresorerieRepository repo) {
        return new CompteTresorerieResolver(repo);
    }

    @Bean
    public GetComptesTresorerieUseCase getComptesTresorerieUseCase(CompteTresorerieRepository repo) {
        return new GetComptesTresorerieUseCase(repo);
    }

    @Bean
    public CreateCompteTresorerieUseCase createCompteTresorerieUseCase(CompteTresorerieRepository repo) {
        return new CreateCompteTresorerieUseCase(repo);
    }

    @Bean
    public UpdateCompteTresorerieUseCase updateCompteTresorerieUseCase(CompteTresorerieRepository repo) {
        return new UpdateCompteTresorerieUseCase(repo);
    }

    // ----- Finance (créances) -----
    @Bean
    public GetBalanceAgeeUseCase getBalanceAgeeUseCase(CreanceRepository repo) {
        return new GetBalanceAgeeUseCase(repo);
    }

    @Bean
    public GetCreancesChauffeurUseCase getCreancesChauffeurUseCase(CreanceRepository repo) {
        return new GetCreancesChauffeurUseCase(repo);
    }

    @Bean
    public GetBalanceAgeeParVehiculeUseCase getBalanceAgeeParVehiculeUseCase(CreanceRepository repo) {
        return new GetBalanceAgeeParVehiculeUseCase(repo);
    }

    @Bean
    public GetCreancesVehiculeUseCase getCreancesVehiculeUseCase(CreanceRepository repo) {
        return new GetCreancesVehiculeUseCase(repo);
    }

    @Bean
    public GetMontantAReverserEtatUseCase getMontantAReverserEtatUseCase(CreanceRepository repo) {
        return new GetMontantAReverserEtatUseCase(repo);
    }

    // ----- Arrêté de compte (restitution des cotisations) -----
    @Bean
    public CalculerCompteCourantUseCase calculerCompteCourantUseCase(
            LigneCotisationRepository ligneCotisationRepository,
            CreanceRepository creanceRepository,
            ChauffeurRepository chauffeurRepository) {
        return new CalculerCompteCourantUseCase(
                ligneCotisationRepository, creanceRepository, chauffeurRepository);
    }

    @Bean
    public GetCompteCourantUseCase getCompteCourantUseCase(CompteCourantRepository repo) {
        return new GetCompteCourantUseCase(repo);
    }

    @Bean
    public GetArreteUseCase getArreteUseCase(ArreteCompteRepository repo,
            CompteCourantRepository compteCourantRepository) {
        return new GetArreteUseCase(repo, compteCourantRepository);
    }

    @Bean
    public ArreterCompteUseCase arreterCompteUseCase(
            CalculerCompteCourantUseCase calculerCompteCourantUseCase,
            ArreteCompteRepository arreteCompteRepository,
            LigneCotisationRepository ligneCotisationRepository,
            LigneRecetteRepository ligneRecetteRepository,
            EncaissementRepository encaissementRepository,
            LignePenaliteRepository lignePenaliteRepository,
            EncaissementPenaliteRepository encaissementPenaliteRepository,
            ContraventionRepository contraventionRepository,
            OperationFinanciereRepository operationFinanciereRepository,
            CategorieOperationRepository categorieOperationRepository,
            CompteTresorerieResolver compteTresorerieResolver,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new ArreterCompteUseCase(
                calculerCompteCourantUseCase, arreteCompteRepository, ligneCotisationRepository,
                ligneRecetteRepository, encaissementRepository, lignePenaliteRepository,
                encaissementPenaliteRepository, contraventionRepository, operationFinanciereRepository,
                categorieOperationRepository, compteTresorerieResolver, periodeClotureeGuard);
    }

    @Bean
    public AnnulerArreteUseCase annulerArreteUseCase(
            ArreteCompteRepository arreteCompteRepository,
            LigneCotisationRepository ligneCotisationRepository,
            LigneRecetteRepository ligneRecetteRepository,
            EncaissementRepository encaissementRepository,
            LignePenaliteRepository lignePenaliteRepository,
            EncaissementPenaliteRepository encaissementPenaliteRepository,
            ContraventionRepository contraventionRepository,
            OperationFinanciereRepository operationFinanciereRepository,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new AnnulerArreteUseCase(
                arreteCompteRepository, ligneCotisationRepository, ligneRecetteRepository,
                encaissementRepository, lignePenaliteRepository, encaissementPenaliteRepository,
                contraventionRepository, operationFinanciereRepository, periodeClotureeGuard);
    }

    @Bean
    public GetArreteDecompteUseCase getArreteDecompteUseCase(
            GetArreteUseCase getArreteUseCase,
            ArreteDocumentRenderer arreteDocumentRenderer) {
        return new GetArreteDecompteUseCase(getArreteUseCase, arreteDocumentRenderer);
    }

    // ----- Trésorerie V2 : transferts + clôture de caisse -----
    @Bean
    public CreateTransfertUseCase createTransfertUseCase(
            TransfertTresorerieRepository transfertRepository,
            CompteTresorerieRepository compteTresorerieRepository,
            PeriodeClotureeGuard periodeClotureeGuard) {
        return new CreateTransfertUseCase(transfertRepository, compteTresorerieRepository,
                periodeClotureeGuard);
    }

    @Bean
    public GetTransfertsUseCase getTransfertsUseCase(TransfertTresorerieRepository repo) {
        return new GetTransfertsUseCase(repo);
    }

    @Bean
    public CloturerCaisseUseCase cloturerCaisseUseCase(
            CompteTresorerieRepository compteTresorerieRepository,
            ClotureCaisseRepository clotureCaisseRepository,
            OperationFinanciereRepository operationFinanciereRepository,
            CategorieOperationRepository categorieOperationRepository) {
        return new CloturerCaisseUseCase(compteTresorerieRepository, clotureCaisseRepository,
                operationFinanciereRepository, categorieOperationRepository);
    }

    @Bean
    public GetCloturesCaisseUseCase getCloturesCaisseUseCase(ClotureCaisseRepository repo) {
        return new GetCloturesCaisseUseCase(repo);
    }

    // ----- Finance V2/V3 : résultat, bilan, clôture, export -----
    @Bean
    public PeriodeClotureeGuard periodeClotureeGuard(CloturePeriodeRepository repo) {
        return new PeriodeClotureeGuard(repo);
    }

    @Bean
    public GetCompteResultatUseCase getCompteResultatUseCase(FinanceReportingRepository repo) {
        return new GetCompteResultatUseCase(repo);
    }

    @Bean
    public GetMargesParVehiculeUseCase getMargesParVehiculeUseCase(FinanceReportingRepository repo) {
        return new GetMargesParVehiculeUseCase(repo);
    }

    @Bean
    public GetRapportFinancierUseCase getRapportFinancierUseCase(OperationFinanciereRepository repo) {
        return new GetRapportFinancierUseCase(repo);
    }

    @Bean
    public GetBilanUseCase getBilanUseCase(
            CompteTresorerieRepository compteTresorerieRepository,
            CreanceRepository creanceRepository,
            FinanceReportingRepository reportingRepository) {
        return new GetBilanUseCase(compteTresorerieRepository, creanceRepository,
                reportingRepository);
    }

    @Bean
    public ExportComptableUseCase exportComptableUseCase(OperationFinanciereRepository repo) {
        return new ExportComptableUseCase(repo);
    }

    @Bean
    public CloturerPeriodeUseCase cloturerPeriodeUseCase(CloturePeriodeRepository repo) {
        return new CloturerPeriodeUseCase(repo);
    }

    @Bean
    public GetCloturesPeriodeUseCase getCloturesPeriodeUseCase(CloturePeriodeRepository repo) {
        return new GetCloturesPeriodeUseCase(repo);
    }

    // ----- Jours fériés -----
    @Bean
    public JoursFeriesCalculator joursFeriesCalculator() {
        return new JoursFeriesCalculator();
    }

    @Bean
    public GetJoursFeriesUseCase getJoursFeriesUseCase(JourFerieRepository repo) {
        return new GetJoursFeriesUseCase(repo);
    }

    @Bean
    public CreateJourFerieUseCase createJourFerieUseCase(JourFerieRepository repo) {
        return new CreateJourFerieUseCase(repo);
    }

    @Bean
    public DeleteJourFerieUseCase deleteJourFerieUseCase(JourFerieRepository repo) {
        return new DeleteJourFerieUseCase(repo);
    }

    @Bean
    public SeedJoursFeriesUseCase seedJoursFeriesUseCase(
            JourFerieRepository repo, JoursFeriesCalculator calculator) {
        return new SeedJoursFeriesUseCase(repo, calculator);
    }
}
