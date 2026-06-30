package com.tmk.vtcmanager.interfaces.rest.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.usecases.operationFinanciere.*;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.OperationFinanciereRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.OperationFinanciereResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper.OperationFinanciereRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/operations-financieres")
@RequiredArgsConstructor
public class OperationFinanciereController {

    private final CreateOperationFinanciereUseCase createUseCase;
    private final UpdateOperationFinanciereUseCase updateUseCase;
    private final DeleteOperationFinanciereUseCase deleteUseCase;
    private final GetOperationFinanciereByIdUseCase getByIdUseCase;
    private final GetAllOperationsFinancieresUseCase getAllUseCase;
    private final AnnulerOperationFinanciereUseCase annulerUseCase;
    private final OperationFinanciereRestMapper mapper;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OperationFinanciereResponse create(@Valid @RequestBody OperationFinanciereRequest request) {
        return mapper.toResponse(createUseCase.execute(mapper.toDomain(request)));
    }

    @GetMapping
    public List<OperationFinanciereResponse> findAll(
            @RequestParam(required = false) TypeOperation typeOperation,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin,
            @RequestParam(required = false) StatutOperation statut,
            @RequestParam(required = false) String recherche,
            @RequestParam(required = false) String categorieCode) {
        var filtres = new OperationFinanciereFiltres(typeOperation, debut, fin, statut, recherche, categorieCode);
        return mapper.toResponseList(getAllUseCase.execute(filtres));
    }

    @GetMapping("/{id}")
    public OperationFinanciereResponse findById(@PathVariable Long id) {
        return mapper.toResponse(getByIdUseCase.execute(id));
    }

    @PutMapping("/{id}")
    public OperationFinanciereResponse update(@PathVariable Long id,
                                               @Valid @RequestBody OperationFinanciereRequest request) {
        return mapper.toResponse(updateUseCase.execute(id, mapper.toDomain(request)));
    }

    @PatchMapping("/{id}/annuler")
    public OperationFinanciereResponse annuler(@PathVariable Long id) {
        return mapper.toResponse(annulerUseCase.execute(id));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }
}
