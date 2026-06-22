package com.tmk.vtcmanager.interfaces.rest.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.CreateCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.DeleteCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.GetAllCatalogueElementsMaintenanceUseCase;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.CatalogueElementMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CatalogueElementMaintenanceResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/catalogue-elements-maintenance")
@RequiredArgsConstructor
public class CatalogueElementMaintenanceController {

    private final GetAllCatalogueElementsMaintenanceUseCase getAllUseCase;
    private final CreateCatalogueElementMaintenanceUseCase createUseCase;
    private final DeleteCatalogueElementMaintenanceUseCase deleteUseCase;

    @GetMapping
    public List<CatalogueElementMaintenanceResponse> findAll() {
        return getAllUseCase.execute().stream()
                .map(e -> new CatalogueElementMaintenanceResponse(e.getId(), e.getLibelle(), e.isActif()))
                .toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CatalogueElementMaintenanceResponse create(@Valid @RequestBody CatalogueElementMaintenanceRequest request) {
        CatalogueElementMaintenance created = createUseCase.execute(
                CatalogueElementMaintenance.builder().libelle(request.libelle()).build());
        return new CatalogueElementMaintenanceResponse(created.getId(), created.getLibelle(), created.isActif());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }
}
