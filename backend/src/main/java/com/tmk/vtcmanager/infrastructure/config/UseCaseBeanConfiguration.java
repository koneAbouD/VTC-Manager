package com.tmk.vtcmanager.infrastructure.config;

import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.usecases.conditionTravail.CreateConditionTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.DeleteConditionTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionTravailByIdUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionTravailImpactUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionsTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.UpdateConditionTravailUseCase;
import com.tmk.vtcmanager.application.usecases.dashboard.GetDashboardSummaryUseCase;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.services.AnnulationEncaissementService;
import com.tmk.vtcmanager.application.services.AnnulationMaintenanceService;
import com.tmk.vtcmanager.application.services.ConfigurationRecetteSynchronizer;
import com.tmk.vtcmanager.application.services.IndisponibiliteNettoyageService;
import com.tmk.vtcmanager.application.services.IndisponibiliteSubstitutionService;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.MarqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculePhotoRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
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
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
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
import com.tmk.vtcmanager.application.usecases.recette.*;
import com.tmk.vtcmanager.application.usecases.sousCategorieOperation.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class UseCaseBeanConfiguration {

    // ----- Vehicule -----
    @Bean
    public CreateVehiculeUseCase createVehiculeUseCase(
            VehiculeRepository repo,
            MarqueRepository marqueRepository,
            ModeleRepository modeleRepository,
            TypeVehiculeRepository typeVehiculeRepository,
            TypeActiviteRepository typeActiviteRepository,
            GroupeVehiculeRepository groupeVehiculeRepository) {
        return new CreateVehiculeUseCase(repo, marqueRepository, modeleRepository,
                typeVehiculeRepository, typeActiviteRepository, groupeVehiculeRepository);
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
            ConfigurationRecetteSynchronizer configurationRecetteSynchronizer) {
        return new UpdateVehiculeUseCase(repo, typeActiviteRepository, groupeVehiculeRepository,
                conditionTravailRepository, programmeTravailRepository, configurationRecetteSynchronizer);
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
            LignePenaliteRepository lignePenaliteRepository) {
        return new RecomputeVehiculeStatusUseCase(vehiculeRepository, chauffeurRepository,
                maintenanceRepository, lignePenaliteRepository);
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
    public CreateChauffeurUseCase createChauffeurUseCase(
            ChauffeurRepository repo,
            TypeDocumentRepository typeDocumentRepository,
            DocumentRepository documentRepository,
            FileStoragePort fileStoragePort) {
        return new CreateChauffeurUseCase(repo, typeDocumentRepository, documentRepository, fileStoragePort);
    }

    @Bean
    public UpdateChauffeurUseCase updateChauffeurUseCase(
            ChauffeurRepository repo,
            DocumentRepository documentRepository,
            TypeDocumentRepository typeDocumentRepository,
            FileStoragePort fileStoragePort) {
        return new UpdateChauffeurUseCase(repo, documentRepository, typeDocumentRepository, fileStoragePort);
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
    public PayContraventionUseCase payContraventionUseCase(ContraventionRepository repo) {
        return new PayContraventionUseCase(repo);
    }

    @Bean
    public ReverseContraventionUseCase reverseContraventionUseCase(ContraventionRepository repo) {
        return new ReverseContraventionUseCase(repo);
    }

    // ----- Maintenance -----
    @Bean
    public ScheduleMaintenanceUseCase scheduleMaintenanceUseCase(
            MaintenanceRepository maintenanceRepo,
            VehiculeRepository vehiculeRepo,
            CategorieOperationRepository categorieOperationRepository,
            VehiculeStatutEventPublisher statutEventPublisher) {
        return new ScheduleMaintenanceUseCase(maintenanceRepo, vehiculeRepo,
                categorieOperationRepository, statutEventPublisher);
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
            VehiculeStatutEventPublisher statutEventPublisher) {
        return new CompleteMaintenanceUseCase(repo, operationRepository,
                categorieOperationRepository, sousCategorieOperationRepository, statutEventPublisher);
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
    public CreateCatalogueElementMaintenanceUseCase createCatalogueElementMaintenanceUseCase(CatalogueElementMaintenanceRepository repo) {
        return new CreateCatalogueElementMaintenanceUseCase(repo);
    }

    @Bean
    public DeleteCatalogueElementMaintenanceUseCase deleteCatalogueElementMaintenanceUseCase(CatalogueElementMaintenanceRepository repo) {
        return new DeleteCatalogueElementMaintenanceUseCase(repo);
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
            IndisponibiliteSubstitutionService indisponibiliteSubstitutionService) {
        return new GenererLignesCotisationUseCase(programmeTravailRepository, configurationRecetteRepository,
                ligneCotisationRepository, indisponibiliteSubstitutionService);
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
            CategorieOperationRepository categorieOperationRepository) {
        return new CreateEncaissementCotisationUseCase(
                ligneCotisationRepository, encaissementCotisationRepository,
                operationFinanciereRepository, categorieOperationRepository);
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
            IndisponibiliteSubstitutionService indisponibiliteSubstitutionService) {
        return new GenererLignesRecetteUseCase(programmeTravailRepository, configurationRecetteRepository,
                ligneRecetteRepository, indisponibiliteSubstitutionService);
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
            CategorieOperationRepository categorieOperationRepository) {
        return new CreateEncaissementUseCase(
                ligneRecetteRepository, encaissementRepository,
                configurationRecetteRepository, operationFinanciereRepository,
                categorieOperationRepository);
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
            LignePenaliteRepository lignePenaliteRepository) {
        return new CreateOperationFinanciereUseCase(repo, chauffeurRepository, vehiculeRepository,
                ligneRecetteRepository, ligneCotisationRepository, lignePenaliteRepository);
    }

    @Bean
    public UpdateOperationFinanciereUseCase updateOperationFinanciereUseCase(OperationFinanciereRepository repo) {
        return new UpdateOperationFinanciereUseCase(repo);
    }

    @Bean
    public DeleteOperationFinanciereUseCase deleteOperationFinanciereUseCase(
            OperationFinanciereRepository repo,
            AnnulationEncaissementService annulationEncaissementService) {
        return new DeleteOperationFinanciereUseCase(repo, annulationEncaissementService);
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
            AnnulationMaintenanceService annulationMaintenanceService) {
        return new AnnulerOperationFinanciereUseCase(
                repo, annulationEncaissementService, annulationMaintenanceService);
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
            LignePenaliteRepository lignePenaliteRepository) {
        return new GenererLignesPenaliteUseCase(
                programmeTravailRepository, conditionTravailRepository,
                ligneRecetteRepository, lignePenaliteRepository);
    }

    @Bean
    public CreateEncaissementPenaliteUseCase createEncaissementPenaliteUseCase(
            LignePenaliteRepository lignePenaliteRepository,
            EncaissementPenaliteRepository encaissementPenaliteRepository,
            OperationFinanciereRepository operationFinanciereRepository,
            CategorieOperationRepository categorieOperationRepository) {
        return new CreateEncaissementPenaliteUseCase(
                lignePenaliteRepository, encaissementPenaliteRepository,
                operationFinanciereRepository, categorieOperationRepository);
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
}
