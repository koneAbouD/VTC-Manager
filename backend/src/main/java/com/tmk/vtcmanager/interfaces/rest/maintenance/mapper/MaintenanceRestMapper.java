package com.tmk.vtcmanager.interfaces.rest.maintenance.mapper;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.interfaces.rest.maintenance.dto.request.MaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.maintenance.dto.response.MaintenanceResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.DetailMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CatalogueElementMaintenanceResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.ElementMaintenanceResponse;
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
    @Mapping(target = "partenaire", source = "partenaireId", qualifiedByName = "partenaireRef")
    @Mapping(target = "detailMaintenance", source = "detailMaintenance", qualifiedByName = "detailMaintenanceToDomain")
    Maintenance toDomain(MaintenanceRequest request);

    @Mapping(target = "partenaireId", source = "partenaire.id")
    @Mapping(target = "partenaireNom", source = "partenaire.nom")
    MaintenanceResponse toResponse(Maintenance domain);

    List<MaintenanceResponse> toResponseList(List<Maintenance> domains);

    @Mapping(target = "imageUrl", ignore = true)
    CatalogueElementMaintenanceResponse toCatalogueElementResponse(CatalogueElementMaintenance domain);

    /**
     * Le tiers de la ligne est aplati : l'UI n'a besoin que de l'id et du nom.
     * La quantité sort toujours renseignée — une ligne d'avant la quantité en
     * vaut une, le client n'a pas à connaître ce détail d'histoire.
     */
    @Mapping(target = "partenaireId", source = "partenaire.id")
    @Mapping(target = "partenaireNom", source = "partenaire.nom")
    @Mapping(target = "quantite", expression = "java(domain.getQuantiteEffective())")
    ElementMaintenanceResponse toElementResponse(ElementMaintenance domain);

    @Named("categorieTypeRef")
    default CategorieOperation categorieTypeRef(Long id) {
        if (id == null) return null;
        return CategorieOperation.builder().id(id).build();
    }

    @Named("partenaireRef")
    default Partenaire partenaireRef(Long id) {
        if (id == null) return null;
        return Partenaire.builder().id(id).build();
    }

    @Named("detailMaintenanceToDomain")
    default DetailMaintenance detailMaintenanceToDomain(DetailMaintenanceRequest request) {
        if (request == null) return null;
        // Détail présent mais sans ligne : la requête dit « plus aucun élément »,
        // ce qui n'est pas la même chose que ne pas parler des éléments.
        if (request.elements() == null || request.elements().isEmpty()) {
            return DetailMaintenance.builder().elements(List.of()).build();
        }
        List<ElementMaintenance> elements = request.elements().stream()
                .map(e -> {
                    CatalogueElementMaintenance catalogueRef = e.catalogueElementId() != null
                            ? CatalogueElementMaintenance.builder().id(e.catalogueElementId()).build()
                            : null;
                    return ElementMaintenance.builder()
                            .catalogueElement(catalogueRef)
                            .libelle(e.libelle())
                            .quantite(e.quantite())
                            .montant(e.montant())
                            .partenaire(partenaireRef(e.partenaireId()))
                            .build();
                })
                .collect(Collectors.toList());
        return DetailMaintenance.builder().elements(elements).build();
    }
}
