package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ChauffeurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementCotisationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneCotisationEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring")
public interface LigneCotisationPersistenceMapper {

    @Mapping(target = "vehiculeId", source = "vehicule.id")
    @Mapping(target = "vehiculeImmatriculation", source = "vehicule.immatriculation")
    @Mapping(target = "chauffeurId", source = "chauffeur.id")
    @Mapping(target = "chauffeurNom", source = "chauffeur", qualifiedByName = "chauffeurNomComplet")
    @Mapping(target = "encaissements", source = "encaissements")
    LigneCotisation toDomain(LigneCotisationEntity entity);

    List<LigneCotisation> toDomainList(List<LigneCotisationEntity> entities);

    /** Nom complet « prénom nom » du chauffeur (null si absent). */
    @Named("chauffeurNomComplet")
    default String chauffeurNomComplet(ChauffeurEntity chauffeur) {
        if (chauffeur == null) return null;
        String prenom = chauffeur.getPrenom() != null ? chauffeur.getPrenom() : "";
        String nom = chauffeur.getNom() != null ? chauffeur.getNom() : "";
        String complet = (prenom + " " + nom).trim();
        return complet.isEmpty() ? null : complet;
    }

    @Mapping(target = "ligneCotisationId", source = "ligneCotisation.id")
    @Mapping(target = "operationFinanciereId", source = "operationFinanciere.id")
    EncaissementCotisation toEncaissementDomain(EncaissementCotisationEntity entity);
}
