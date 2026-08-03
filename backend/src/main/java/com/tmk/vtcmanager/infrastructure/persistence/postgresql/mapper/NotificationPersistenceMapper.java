package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.NotificationEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface NotificationPersistenceMapper {

    // creeLe n'a pas de contrepartie ici : la date de création est posée par
    // l'audit JPA (created_at), que le builder Lombok de l'entité n'expose pas.
    NotificationEntity toEntity(Notification domain);

    @Mapping(target = "creeLe", source = "createdAt")
    Notification toDomain(NotificationEntity entity);

    List<Notification> toDomainList(List<NotificationEntity> entities);
}
