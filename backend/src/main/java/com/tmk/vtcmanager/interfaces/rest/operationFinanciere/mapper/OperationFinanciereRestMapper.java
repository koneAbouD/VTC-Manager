package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.mapper.ChauffeurRestMapper;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.DetailMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.ElementMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.OperationFinanciereRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.OperationFinanciereResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.VehiculeRestMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;
import java.util.stream.Collectors;

@Mapper(componentModel = "spring", uses = {
        CategorieOperationRestMapper.class,
        SousCategorieOperationRestMapper.class,
        ChauffeurRestMapper.class,
        VehiculeRestMapper.class
})
public interface OperationFinanciereRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "reference", ignore = true)
    @Mapping(target = "statut", ignore = true)
    @Mapping(target = "categorie", source = "categorieId", qualifiedByName = "categorieRefFromId")
    @Mapping(target = "sousCategorie", source = "sousCategorieId", qualifiedByName = "sousCategorieRefFromId")
    @Mapping(target = "chauffeur", source = "chauffeurId", qualifiedByName = "chauffeurRefFromId")
    @Mapping(target = "vehicule", source = "vehiculeId", qualifiedByName = "vehiculeRefFromId")
    @Mapping(target = "detailMaintenance", source = "detailMaintenance", qualifiedByName = "toDetailMaintenanceDomain")
    OperationFinanciere toDomain(OperationFinanciereRequest request);

    OperationFinanciereResponse toResponse(OperationFinanciere domain);

    List<OperationFinanciereResponse> toResponseList(List<OperationFinanciere> domains);

    @Named("categorieRefFromId")
    default CategorieOperation categorieRefFromId(Long id) {
        if (id == null) return null;
        return CategorieOperation.builder().id(id).build();
    }

    @Named("sousCategorieRefFromId")
    default SousCategorieOperation sousCategorieRefFromId(Long id) {
        if (id == null) return null;
        return SousCategorieOperation.builder().id(id).build();
    }

    @Named("chauffeurRefFromId")
    default Chauffeur chauffeurRefFromId(Long id) {
        if (id == null) return null;
        return Chauffeur.builder().id(id).build();
    }

    @Named("vehiculeRefFromId")
    default Vehicule vehiculeRefFromId(Long id) {
        if (id == null) return null;
        return Vehicule.builder().id(id).build();
    }

    @Named("toDetailMaintenanceDomain")
    default DetailMaintenance toDetailMaintenanceDomain(DetailMaintenanceRequest request) {
        if (request == null) return null;
        List<ElementMaintenance> elements = request.elements() == null ? List.of() :
                request.elements().stream()
                        .map(e -> {
                            if (e.catalogueElementId() == null && (e.libelle() == null || e.libelle().isBlank())) {
                                throw new IllegalArgumentException(
                                        "Chaque élément de maintenance doit avoir un catalogueElementId ou un libelle.");
                            }
                            CatalogueElementMaintenance catalogueRef = e.catalogueElementId() != null
                                    ? CatalogueElementMaintenance.builder().id(e.catalogueElementId()).build()
                                    : null;
                            return ElementMaintenance.builder()
                                    .catalogueElement(catalogueRef)
                                    .libelle(e.libelle())
                                    .montant(e.montant())
                                    .build();
                        })
                        .collect(Collectors.toList());
        return DetailMaintenance.builder()
                .elements(elements)
                .build();
    }
}
