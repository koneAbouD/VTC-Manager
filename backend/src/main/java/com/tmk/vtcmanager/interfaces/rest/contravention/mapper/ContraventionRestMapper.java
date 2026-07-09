package com.tmk.vtcmanager.interfaces.rest.contravention.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.contravention.ApercuImportContraventions;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ResultatImportContraventions;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.mapper.ChauffeurRestMapper;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.ContraventionImportItem;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.ContraventionRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ApercuImportResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ContraventionResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ResultatImportResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.VehiculeRestMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring", uses = {
        ChauffeurRestMapper.class,
        VehiculeRestMapper.class
})
public interface ContraventionRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "statut", ignore = true)
    // Renseignés côté serveur uniquement (jamais depuis une saisie).
    @Mapping(target = "documentSourcePath", ignore = true)
    @Mapping(target = "statutRattachement", ignore = true)
    @Mapping(target = "chauffeur", source = "chauffeurId", qualifiedByName = "contraventionChauffeurFromId")
    @Mapping(target = "vehicule", source = "vehiculeId", qualifiedByName = "contraventionVehiculeFromId")
    Contravention toDomain(ContraventionRequest request);

    ContraventionResponse toResponse(Contravention domain);

    List<ContraventionResponse> toResponseList(List<Contravention> domains);

    // ── Import PDF ────────────────────────────────────────────────────────────

    ApercuImportResponse toApercuResponse(ApercuImportContraventions apercu);

    ResultatImportResponse toResultatResponse(ResultatImportContraventions resultat);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "statut", ignore = true)
    @Mapping(target = "statutRattachement", ignore = true)
    @Mapping(target = "cotisation", ignore = true)
    @Mapping(target = "montantPaye", ignore = true)
    @Mapping(target = "datePaiement", ignore = true)
    @Mapping(target = "description", source = "typeInfraction")
    @Mapping(target = "chauffeur", source = "chauffeurId", qualifiedByName = "contraventionChauffeurFromId")
    @Mapping(target = "vehicule", source = "vehiculeId", qualifiedByName = "contraventionVehiculeFromId")
    Contravention toDomain(ContraventionImportItem item);

    List<Contravention> toImportDomainList(List<ContraventionImportItem> items);

    @Named("contraventionChauffeurFromId")
    default Chauffeur contraventionChauffeurFromId(Long id) {
        if (id == null) return null;
        return Chauffeur.builder().id(id).build();
    }

    @Named("contraventionVehiculeFromId")
    default Vehicule contraventionVehiculeFromId(Long id) {
        if (id == null) return null;
        return Vehicule.builder().id(id).build();
    }
}
