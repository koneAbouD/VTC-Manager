package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VehiculeStatutHistoriqueEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface VehiculeStatutHistoriquePersistenceMapper {

    VehiculeStatutHistoriqueEntity toEntity(VehiculeStatutHistorique domain);

    VehiculeStatutHistorique toDomain(VehiculeStatutHistoriqueEntity entity);

    List<VehiculeStatutHistorique> toDomainList(List<VehiculeStatutHistoriqueEntity> entities);
}
