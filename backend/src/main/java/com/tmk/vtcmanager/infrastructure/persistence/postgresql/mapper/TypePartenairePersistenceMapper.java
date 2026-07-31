package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.partenaire.TypePartenaire;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypePartenaireEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TypePartenairePersistenceMapper {

    TypePartenaireEntity toEntity(TypePartenaire domain);

    TypePartenaire toDomain(TypePartenaireEntity entity);

    List<TypePartenaire> toDomainList(List<TypePartenaireEntity> entities);
}
