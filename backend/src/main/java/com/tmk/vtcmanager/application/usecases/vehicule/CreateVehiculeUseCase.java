package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.*;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.*;
import com.tmk.vtcmanager.application.services.VehiculeStatutHistoriqueService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class CreateVehiculeUseCase {

    private final VehiculeRepository vehiculeRepository;
    private final MarqueRepository marqueRepository;
    private final ModeleRepository modeleRepository;
    private final TypeVehiculeRepository typeVehiculeRepository;
    private final TypeActiviteRepository typeActiviteRepository;
    private final GroupeVehiculeRepository groupeVehiculeRepository;
    private final VehiculeStatutHistoriqueService statutHistoriqueService;

    @Transactional
    public Vehicule execute(CreateVehiculeCommand command) {
        Vehicule.builder()
                .dateMiseEnCirculation(command.dateMiseEnCirculation())
                .dateEntreeFlotte(command.dateEntreeFlotte())
                .build()
                .validateDates();

        if (vehiculeRepository.findByImmatriculation(command.immatriculation()).isPresent()) {
            throw ResourceAlreadyExistsException.of("Véhicule", "immatriculation", command.immatriculation());
        }

        Marque marque = marqueRepository.findById(command.marqueId())
                .orElseThrow(() -> ResourceNotFoundException.of("Marque", command.marqueId()));

        Modele modele = modeleRepository.findById(command.modeleId())
                .orElseThrow(() -> ResourceNotFoundException.of("Modele", command.modeleId()));

        TypeVehicule typeVehicule = null;
        if (command.typeVehiculeId() != null) {
            typeVehicule = typeVehiculeRepository.findById(command.typeVehiculeId())
                    .orElseThrow(() -> ResourceNotFoundException.of("TypeVehicule", command.typeVehiculeId()));
        }

        TypeActivite typeActivite = null;
        if (command.typeActiviteId() != null) {
            typeActivite = typeActiviteRepository.findById(command.typeActiviteId())
                    .orElseThrow(() -> ResourceNotFoundException.of("TypeActivite", command.typeActiviteId()));
        }

        var groupe = command.groupeId() != null
                ? groupeVehiculeRepository.findById(command.groupeId())
                    .orElseThrow(() -> ResourceNotFoundException.of("GroupeVehicule", command.groupeId()))
                : null;

        Vehicule vehiculeToCreate = Vehicule.builder()
                .immatriculation(command.immatriculation())
                .marque(marque)
                .modele(modele)
                .type(typeVehicule)
                .activite(typeActivite)
                .groupe(groupe)
                .numeroChassis(command.numeroChassis())
                .numeroTelephoneVehicule(command.numeroTelephoneVehicule())
                .numeroTelephoneBalise(command.numeroTelephoneBalise())
                .identifiantBalise(command.identifiantBalise())
                .couleur(command.couleur())
                .kilometrage(command.kilometrage())
                .statut(command.statut() != null ? command.statut() : VehiculeStatus.DISPONIBLE)
                .dateAchat(command.dateAchat())
                .dateProchaineMaintenance(command.dateProchaineMaintenance())
                .dateMiseEnCirculation(command.dateMiseEnCirculation())
                .dateEntreeFlotte(command.dateEntreeFlotte())
                .build();

        Vehicule saved = vehiculeRepository.save(vehiculeToCreate);
        statutHistoriqueService.enregistrerTransition(saved.getId(), saved.getStatut(),
                VehiculeStatutMotif.ENTREE_FLOTTE);
        return saved;
    }
}
