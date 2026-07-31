package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.FacturePartenaireEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PartenaireEntity;
import org.mapstruct.Mapper;

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

    FacturePartenaire toDomain(FacturePartenaireEntity entity);

    List<FacturePartenaire> toFactureDomainList(List<FacturePartenaireEntity> entities);
}
