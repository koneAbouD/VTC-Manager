package com.tmk.vtcmanager.interfaces.rest.penalite.mapper;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.request.EncaissementPenaliteRequest;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.request.LignePenaliteRequest;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.response.EncaissementPenaliteResponse;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.response.LignePenaliteResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.math.BigDecimal;
import java.util.List;

@Mapper(componentModel = "spring",
        imports = {TypePenalite.class, TypeSanction.class, ModePaiement.class})
public interface PenaliteRestMapper {

    @Mapping(target = "typePenalite",  expression = "java(TypePenalite.valueOf(request.typePenalite()))")
    @Mapping(target = "typeSanction",  expression = "java(TypeSanction.valueOf(request.typeSanction()))")
    @Mapping(target = "id",            ignore = true)
    @Mapping(target = "vehiculeImmatriculation", ignore = true)
    @Mapping(target = "chauffeurNomComplet",      ignore = true)
    @Mapping(target = "montantEncaisse", ignore = true)
    @Mapping(target = "dureeSanctionSecondes",      source = "dureeSanctionSecondes")
    @Mapping(target = "dureeImmobilisationMinutes", source = "dureeImmobilisationMinutes")
    @Mapping(target = "dateDebutImmobilisation", ignore = true)
    @Mapping(target = "dateFinImmobilisation",   ignore = true)
    @Mapping(target = "dateGeneration", ignore = true)
    @Mapping(target = "ligneRecetteId", ignore = true)
    @Mapping(target = "statut",         ignore = true)
    @Mapping(target = "encaissements",  ignore = true)
    @Mapping(target = "motifAnnulation", ignore = true)
    LignePenalite toDomain(LignePenaliteRequest request);

    @Mapping(target = "modeEncaissement", expression = "java(ModePaiement.valueOf(request.modeEncaissement()))")
    @Mapping(target = "id",                    ignore = true)
    @Mapping(target = "lignePenaliteId",       ignore = true)
    @Mapping(target = "operationFinanciereId", ignore = true)
    EncaissementPenalite toDomain(EncaissementPenaliteRequest request);

    @Mapping(target = "montantRestant", expression = "java(computeRestant(ligne))")
    @Mapping(target = "typePenalite",  expression = "java(ligne.getTypePenalite() != null ? ligne.getTypePenalite().name() : null)")
    @Mapping(target = "typeSanction",  expression = "java(ligne.getTypeSanction() != null ? ligne.getTypeSanction().name() : null)")
    @Mapping(target = "statut",        expression = "java(ligne.getStatut() != null ? ligne.getStatut().name() : null)")
    LignePenaliteResponse toResponse(LignePenalite ligne);

    List<LignePenaliteResponse> toResponseList(List<LignePenalite> lignes);

    @Mapping(target = "modeEncaissement", expression = "java(e.getModeEncaissement() != null ? e.getModeEncaissement().name() : null)")
    EncaissementPenaliteResponse toEncaissementResponse(EncaissementPenalite e);

    List<EncaissementPenaliteResponse> toEncaissementResponseList(List<EncaissementPenalite> list);

    default BigDecimal computeRestant(LignePenalite ligne) {
        return ligne.montantRestant();
    }
}
