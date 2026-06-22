package com.tmk.vtcmanager.interfaces.rest.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.usecases.categorieOperation.*;
import com.tmk.vtcmanager.application.usecases.sousCategorieOperation.*;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.CategorieOperationRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.SousCategorieOperationRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CategorieOperationResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.SousCategorieOperationResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper.CategorieOperationRestMapper;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper.SousCategorieOperationRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categories-operation")
@RequiredArgsConstructor
public class CategorieOperationController {

    private final CreateCategorieOperationUseCase createUseCase;
    private final UpdateCategorieOperationUseCase updateUseCase;
    private final DeleteCategorieOperationUseCase deleteUseCase;
    private final GetCategorieOperationByIdUseCase getByIdUseCase;
    private final GetAllCategoriesOperationUseCase getAllUseCase;
    private final GetCategorieOperationBySousCategorieUseCase getBySousCategorieUseCase;
    private final CategorieOperationRestMapper mapper;

    private final CreateSousCategorieOperationUseCase createSousCategorieUseCase;
    private final UpdateSousCategorieOperationUseCase updateSousCategorieUseCase;
    private final DeleteSousCategorieOperationUseCase deleteSousCategorieUseCase;
    private final GetAllSousCategoriesOperationUseCase getSousCategorieUseCase;
    private final SousCategorieOperationRestMapper sousCategorieMapper;

    // ----- CategorieOperation -----

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CategorieOperationResponse create(@Valid @RequestBody CategorieOperationRequest request) {
        return mapper.toResponse(createUseCase.execute(mapper.toDomain(request)));
    }

    @GetMapping
    public List<CategorieOperationResponse> findAll(
            @RequestParam(required = false) TypeOperation typeOperation,
            @RequestParam(required = false) String sousCategorieCode,
            @RequestParam(required = false) String sousCategorieLibelle,
            @RequestParam(defaultValue = "false") boolean includeSousCategorie) {
        return mapper.toResponseList(
                getAllUseCase.execute(typeOperation, sousCategorieCode, sousCategorieLibelle, includeSousCategorie));
    }

    @GetMapping("/{id}")
    public CategorieOperationResponse findById(
            @PathVariable Long id,
            @RequestParam(defaultValue = "false") boolean includeSousCategorie) {
        return mapper.toResponse(getByIdUseCase.execute(id, includeSousCategorie));
    }

    @PutMapping("/{id}")
    public CategorieOperationResponse update(@PathVariable Long id,
                                              @Valid @RequestBody CategorieOperationRequest request) {
        return mapper.toResponse(updateUseCase.execute(id, mapper.toDomain(request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/search")
    public CategorieOperationResponse findBySousCategorie(
            @RequestParam(required = false) Long sousCategorieId,
            @RequestParam(required = false) String sousCategorieCode,
            @RequestParam(defaultValue = "false") boolean includeSousCategorie) {
        return mapper.toResponse(
                getBySousCategorieUseCase.execute(sousCategorieId, sousCategorieCode, includeSousCategorie));
    }

    // ----- SousCategorieOperation -----

    @PostMapping("/{categorieId}/sous-categorie")
    @ResponseStatus(HttpStatus.CREATED)
    public SousCategorieOperationResponse createSousCategorie(
            @PathVariable Long categorieId,
            @Valid @RequestBody SousCategorieOperationRequest request) {
        SousCategorieOperation domain = sousCategorieMapper.toDomain(request);
        domain.setCategorieId(categorieId);
        return sousCategorieMapper.toResponse(createSousCategorieUseCase.execute(domain));
    }

    @GetMapping("/{categorieId}/sous-categorie")
    public ResponseEntity<SousCategorieOperationResponse> findSousCategorie(@PathVariable Long categorieId) {
        return getSousCategorieUseCase.execute(categorieId)
                .map(sousCategorieMapper::toResponse)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{categorieId}/sous-categorie/{sousCategorieId}")
    public SousCategorieOperationResponse updateSousCategorie(
            @PathVariable Long categorieId,
            @PathVariable Long sousCategorieId,
            @Valid @RequestBody SousCategorieOperationRequest request) {
        SousCategorieOperation domain = sousCategorieMapper.toDomain(request);
        domain.setCategorieId(categorieId);
        return sousCategorieMapper.toResponse(updateSousCategorieUseCase.execute(sousCategorieId, domain));
    }

    @DeleteMapping("/{categorieId}/sous-categorie/{sousCategorieId}")
    public ResponseEntity<Void> deleteSousCategorie(
            @PathVariable Long categorieId,
            @PathVariable Long sousCategorieId) {
        deleteSousCategorieUseCase.execute(sousCategorieId);
        return ResponseEntity.noContent().build();
    }
}
