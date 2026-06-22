package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.CotisationTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ConditionTravailEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CotisationTemplateEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PenaliteTemplateEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface ConditionTravailPersistenceMapper {

    @Mapping(target = "cotisations", source = "cotisations")
    @Mapping(target = "penalites", source = "penalites")
    ConditionTravail toDomain(ConditionTravailEntity entity);

    List<ConditionTravail> toDomainList(List<ConditionTravailEntity> entities);

    CotisationTemplate toDomain(CotisationTemplateEntity entity);

    PenaliteTemplate toDomain(PenaliteTemplateEntity entity);
}
