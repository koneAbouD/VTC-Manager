package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.notification.DeviceToken;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.DeviceTokenEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface DeviceTokenPersistenceMapper {

    DeviceTokenEntity toEntity(DeviceToken domain);

    DeviceToken toDomain(DeviceTokenEntity entity);

    List<DeviceToken> toDomainList(List<DeviceTokenEntity> entities);
}
