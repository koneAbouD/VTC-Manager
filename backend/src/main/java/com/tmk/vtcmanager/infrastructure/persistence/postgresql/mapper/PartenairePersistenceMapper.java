package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.FacturePartenaireEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PartenaireEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        CategorieOperationPersistenceMapper.class,
        VehiculePersistenceMapper.class,
        TypePartenairePersistenceMapper.class
})
public interface PartenairePersistenceMapper {

    PartenaireEntity toEntity(Partenaire domain);

    Partenaire toDomain(PartenaireEntity entity);

    List<Partenaire> toDomainList(List<PartenaireEntity> entities);

    FacturePartenaireEntity toEntity(FacturePartenaire domain);

    /**
     * Les lignes de la dette ne sont pas portées par l'entité : elles sont
     * reconstituées à part depuis les éléments de maintenance
     * ({@code lignesParFacture}) et rattachées par le use case.
     */
    @Mapping(target = "lignes", ignore = true)
    FacturePartenaire toDomain(FacturePartenaireEntity entity);

    List<FacturePartenaire> toFactureDomainList(List<FacturePartenaireEntity> entities);
}
