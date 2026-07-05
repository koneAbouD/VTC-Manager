package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ChauffeurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.EncaissementEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneRecetteEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring")
public interface LigneRecettePersistenceMapper {

    @Mapping(target = "vehiculeId", source = "vehicule.id")
    @Mapping(target = "vehiculeImmatriculation", source = "vehicule.immatriculation")
    @Mapping(target = "chauffeurId", source = "chauffeur.id")
    @Mapping(target = "chauffeurNom", source = "chauffeur", qualifiedByName = "chauffeurNomComplet")
    @Mapping(target = "encaissements", source = "encaissements")
    LigneRecette toDomain(LigneRecetteEntity entity);

    List<LigneRecette> toDomainList(List<LigneRecetteEntity> entities);

    /** Nom complet « prénom nom » du chauffeur (null si absent). */
    @Named("chauffeurNomComplet")
    default String chauffeurNomComplet(ChauffeurEntity chauffeur) {
        if (chauffeur == null) return null;
        String prenom = chauffeur.getPrenom() != null ? chauffeur.getPrenom() : "";
        String nom = chauffeur.getNom() != null ? chauffeur.getNom() : "";
        String complet = (prenom + " " + nom).trim();
        return complet.isEmpty() ? null : complet;
    }

    @Mapping(target = "ligneRecetteId", source = "ligneRecette.id")
    @Mapping(target = "operationFinanciereId", source = "operationFinanciere.id")
    Encaissement toEncaissementDomain(EncaissementEntity entity);
}
