package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.fournisseur.FactureFournisseur;
import com.tmk.vtcmanager.application.domain.fournisseur.Fournisseur;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.FactureFournisseurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.FournisseurEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        CategorieOperationPersistenceMapper.class,
        VehiculePersistenceMapper.class
})
public interface FournisseurPersistenceMapper {

    FournisseurEntity toEntity(Fournisseur domain);

    Fournisseur toDomain(FournisseurEntity entity);

    List<Fournisseur> toDomainList(List<FournisseurEntity> entities);

    FactureFournisseurEntity toEntity(FactureFournisseur domain);

    FactureFournisseur toDomain(FactureFournisseurEntity entity);

    List<FactureFournisseur> toFactureDomainList(List<FactureFournisseurEntity> entities);
}
