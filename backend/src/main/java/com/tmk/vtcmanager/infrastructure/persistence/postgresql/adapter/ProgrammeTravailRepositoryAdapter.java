package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ProgrammeChauffeurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ProgrammeTravailEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ChauffeurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ProgrammeTravailJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.ProgrammeTravailPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ProgrammeTravailRepositoryAdapter implements ProgrammeTravailRepository {

    private final ProgrammeTravailJpaRepository programmeJpaRepository;
    private final VehiculeJpaRepository vehiculeJpaRepository;
    private final ChauffeurJpaRepository chauffeurJpaRepository;
    private final ProgrammeTravailPersistenceMapper mapper;

    @Override
    @Transactional(readOnly = true)
    public Optional<ProgrammeTravail> findByVehiculeId(Long vehiculeId) {
        return programmeJpaRepository.findByVehiculeId(vehiculeId).map(mapper::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<ProgrammeTravail> findByChauffeurId(Long chauffeurId) {
        return programmeJpaRepository.findByChauffeurId(chauffeurId)
                .stream()
                .findFirst()
                .map(mapper::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ProgrammeTravail> findAllWithChauffeurs() {
        return programmeJpaRepository.findAllWithChauffeurs().stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    @Transactional
    public ProgrammeTravail save(ProgrammeTravail programme) {
        ProgrammeTravailEntity entity = programmeJpaRepository
                .findByVehiculeId(programme.getVehiculeId())
                .orElseGet(ProgrammeTravailEntity::new);

        entity.setVehicule(vehiculeJpaRepository.getReferenceById(programme.getVehiculeId()));
        entity.setNombreChauffeursAutorises(programme.getNombreChauffeursAutorises());
        entity.setTypeProgramme(programme.getTypeProgramme());
        entity.setHeureDebutService(programme.getHeureDebutService());
        entity.setHeureFinService(programme.getHeureFinService());
        entity.setModeAlternance(programme.getModeAlternance());
        entity.setJoursAlternance(programme.getJoursAlternance());
        entity.setDateDebutAlternance(programme.getDateDebutAlternance());
        entity.setJourSalaireActif(programme.isJourSalaireActif());
        entity.setJourSalaire(programme.getJourSalaire());
        entity.setJoursAlternanceSemaine(programme.getJoursAlternanceSemaine() != null
                ? new java.util.HashSet<>(programme.getJoursAlternanceSemaine())
                : new java.util.HashSet<>());
        entity.setJoursTravailSemaine(programme.getJoursTravailSemaine() != null
                ? new java.util.HashSet<>(programme.getJoursTravailSemaine())
                : new java.util.HashSet<>());

        if (entity.getChauffeurs() == null) {
            entity.setChauffeurs(new ArrayList<>());
        }
        entity.getChauffeurs().clear();

        List<ProgrammeChauffeur> chauffeurs = new ArrayList<>(programme.getChauffeurs());
        chauffeurs.sort(Comparator.comparing(
                pc -> pc.getOrdreAlternance() == null ? Integer.MAX_VALUE : pc.getOrdreAlternance()
        ));

        for (ProgrammeChauffeur pc : chauffeurs) {
            ProgrammeChauffeurEntity chauffeurEntity = ProgrammeChauffeurEntity.builder()
                    .programme(entity)
                    .chauffeur(chauffeurJpaRepository.getReferenceById(pc.getChauffeurId()))
                    .ordreAlternance(pc.getOrdreAlternance())
                    .ordreJourSalaire(pc.getOrdreJourSalaire())
                    .dateService(pc.getDateService())
                    .build();
            entity.getChauffeurs().add(chauffeurEntity);
        }

        return mapper.toDomain(programmeJpaRepository.save(entity));
    }
}
