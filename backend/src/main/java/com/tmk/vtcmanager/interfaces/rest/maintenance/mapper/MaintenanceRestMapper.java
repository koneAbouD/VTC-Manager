package com.tmk.vtcmanager.interfaces.rest.maintenance.mapper;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.interfaces.rest.maintenance.dto.request.MaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.maintenance.dto.response.MaintenanceResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.DetailMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper.CategorieOperationRestMapper;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.VehiculeRestMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;
import java.util.stream.Collectors;

@Mapper(componentModel = "spring", uses = {VehiculeRestMapper.class, CategorieOperationRestMapper.class})
public interface MaintenanceRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "vehicule", ignore = true)
    @Mapping(target = "statutAvantCompletion", ignore = true)
    @Mapping(target = "categorieType", source = "categorieTypeId", qualifiedByName = "categorieTypeRef")
    @Mapping(target = "detailMaintenance", source = "detailMaintenance", qualifiedByName = "detailMaintenanceToDomain")
    Maintenance toDomain(MaintenanceRequest request);

    MaintenanceResponse toResponse(Maintenance domain);

    List<MaintenanceResponse> toResponseList(List<Maintenance> domains);

    @Named("categorieTypeRef")
    default CategorieOperation categorieTypeRef(Long id) {
        if (id == null) return null;
        return CategorieOperation.builder().id(id).build();
    }

    @Named("detailMaintenanceToDomain")
    default DetailMaintenance detailMaintenanceToDomain(DetailMaintenanceRequest request) {
        if (request == null || request.elements() == null || request.elements().isEmpty()) return null;
        List<ElementMaintenance> elements = request.elements().stream()
                .map(e -> {
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
        return DetailMaintenance.builder().elements(elements).build();
    }
}
