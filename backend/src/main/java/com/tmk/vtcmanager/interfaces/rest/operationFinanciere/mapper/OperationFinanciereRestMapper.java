package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.SoldePeriode;
import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.mapper.ChauffeurRestMapper;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.DetailMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.ElementMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.OperationFinanciereRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CatalogueElementMaintenanceResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.ElementMaintenanceResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.OperationFinanciereResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.SoldePeriodeResponse;
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
    @Mapping(target = "dateReference", ignore = true)
    @Mapping(target = "maintenanceId", ignore = true)
    @Mapping(target = "compteTresorerieId", ignore = true)
    @Mapping(target = "categorie", source = "categorieId", qualifiedByName = "categorieRefFromId")
    @Mapping(target = "sousCategorie", source = "sousCategorieId", qualifiedByName = "sousCategorieRefFromId")
    @Mapping(target = "chauffeur", source = "chauffeurId", qualifiedByName = "chauffeurRefFromId")
    @Mapping(target = "vehicule", source = "vehiculeId", qualifiedByName = "vehiculeRefFromId")
    @Mapping(target = "partenaire", source = "partenaireId", qualifiedByName = "partenaireRefFromId")
    @Mapping(target = "detailMaintenance", source = "detailMaintenance", qualifiedByName = "toDetailMaintenanceDomain")
    OperationFinanciere toDomain(OperationFinanciereRequest request);

    @Mapping(target = "partenaireId", source = "partenaire.id")
    @Mapping(target = "partenaireNom", source = "partenaire.nom")
    OperationFinanciereResponse toResponse(OperationFinanciere domain);

    List<OperationFinanciereResponse> toResponseList(List<OperationFinanciere> domains);

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

    default SoldePeriodeResponse toSoldeResponse(SoldePeriode solde) {
        return new SoldePeriodeResponse(solde.revenus(), solde.depenses(), solde.solde());
    }

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

    @Named("partenaireRefFromId")
    default Partenaire partenaireRefFromId(Long id) {
        if (id == null) return null;
        return Partenaire.builder().id(id).build();
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
                                    .quantite(e.quantite())
                                    .montant(e.montant())
                                    .partenaire(partenaireRefFromId(e.partenaireId()))
                                    .build();
                        })
                        .collect(Collectors.toList());
        return DetailMaintenance.builder()
                .elements(elements)
                .build();
    }
}
