package com.tmk.vtcmanager.interfaces.rest.conditionTravail.mapper;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.CotisationTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.request.CreateConditionTravailRequest;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.request.CotisationTemplateRequest;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.request.PenaliteTemplateRequest;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response.ConditionTravailResponse;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response.CotisationTemplateResponse;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response.PenaliteTemplateResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface ConditionTravailRestMapper {

    @Mapping(target = "id", ignore = true)
    ConditionTravail toDomain(CreateConditionTravailRequest request);

    @Mapping(target = "id", ignore = true)
    CotisationTemplate toDomain(CotisationTemplateRequest request);

    @Mapping(target = "id", ignore = true)
    PenaliteTemplate toDomain(PenaliteTemplateRequest request);

    ConditionTravailResponse toResponse(ConditionTravail domain);

    CotisationTemplateResponse toResponse(CotisationTemplate domain);

    PenaliteTemplateResponse toResponse(PenaliteTemplate domain);

    List<ConditionTravailResponse> toResponseList(List<ConditionTravail> domains);

    List<PenaliteTemplateResponse> toPenaliteResponseList(List<PenaliteTemplate> domains);

    List<PenaliteTemplate> toPenaliteDomainList(List<PenaliteTemplateRequest> requests);
}
