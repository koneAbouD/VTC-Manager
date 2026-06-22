package com.tmk.vtcmanager.interfaces.rest.document;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.usecases.document.*;
import com.tmk.vtcmanager.interfaces.rest.document.dto.TypeDocumentRequest;
import com.tmk.vtcmanager.interfaces.rest.document.dto.TypeDocumentResponse;
import com.tmk.vtcmanager.interfaces.rest.document.mapper.DocumentRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/types-document")
@RequiredArgsConstructor
@Tag(name = "Types de Document", description = "Référentiel des types de documents (carte grise, assurance, permis…)")
public class TypeDocumentController {

    private final GetAllTypesDocumentUseCase getAllUseCase;
    private final GetTypesDocumentByCibleUseCase getByCibleUseCase;
    private final CreateTypeDocumentUseCase createUseCase;
    private final UpdateTypeDocumentUseCase updateUseCase;
    private final DeleteTypeDocumentUseCase deleteUseCase;
    private final DocumentRestMapper mapper;

    @GetMapping
    @Operation(summary = "Lister tous les types de document")
    public ResponseEntity<List<TypeDocumentResponse>> getAll() {
        return ResponseEntity.ok(mapper.toTypeResponseList(getAllUseCase.execute()));
    }

    @GetMapping("/cible/{cible}")
    @Operation(summary = "Lister les types de document par cible",
               description = "Retourne les types pour VEHICULE, CHAUFFEUR ou LES_DEUX (inclut toujours LES_DEUX)")
    public ResponseEntity<List<TypeDocumentResponse>> getByCible(@PathVariable CibleDocument cible) {
        return ResponseEntity.ok(mapper.toTypeResponseList(getByCibleUseCase.execute(cible)));
    }

    @PostMapping
    @Operation(summary = "Créer un type de document")
    public ResponseEntity<TypeDocumentResponse> create(@Valid @RequestBody TypeDocumentRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(mapper.toTypeResponse(createUseCase.execute(mapper.toDomain(request))));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Mettre à jour un type de document")
    public ResponseEntity<TypeDocumentResponse> update(
            @PathVariable Long id,
            @Valid @RequestBody TypeDocumentRequest request) {
        return ResponseEntity.ok(mapper.toTypeResponse(updateUseCase.execute(id, mapper.toDomain(request))));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Supprimer un type de document")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }
}