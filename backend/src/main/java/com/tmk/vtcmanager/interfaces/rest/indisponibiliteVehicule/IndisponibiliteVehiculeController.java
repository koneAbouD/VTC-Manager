package com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule.CreateIndisponibiliteVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule.DeleteIndisponibiliteVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule.GetAllIndisponibilitesVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule.GetIndisponibiliteVehiculeByIdUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule.TerminerIndisponibiliteVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule.UpdateIndisponibiliteVehiculeUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule.dto.request.IndisponibiliteVehiculeRequest;
import com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule.dto.response.IndisponibiliteVehiculeResponse;
import com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule.mapper.IndisponibiliteVehiculeRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/indisponibilites-vehicule")
@RequiredArgsConstructor
public class IndisponibiliteVehiculeController {

    private final CreateIndisponibiliteVehiculeUseCase createIndisponibiliteVehiculeUseCase;
    private final UpdateIndisponibiliteVehiculeUseCase updateIndisponibiliteVehiculeUseCase;
    private final DeleteIndisponibiliteVehiculeUseCase deleteIndisponibiliteVehiculeUseCase;
    private final GetIndisponibiliteVehiculeByIdUseCase getIndisponibiliteVehiculeByIdUseCase;
    private final GetAllIndisponibilitesVehiculeUseCase getAllIndisponibilitesVehiculeUseCase;
    private final TerminerIndisponibiliteVehiculeUseCase terminerIndisponibiliteVehiculeUseCase;
    private final IndisponibiliteVehiculeRestMapper mapper;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public IndisponibiliteVehiculeResponse create(@Valid @RequestBody IndisponibiliteVehiculeRequest request) {
        IndisponibiliteVehicule created = createIndisponibiliteVehiculeUseCase.execute(mapper.toDomain(request));
        return mapper.toResponse(created);
    }

    @GetMapping
    public List<IndisponibiliteVehiculeResponse> findAll(@RequestParam(required = false) Long vehiculeId) {
        return mapper.toResponseList(getAllIndisponibilitesVehiculeUseCase.execute(vehiculeId));
    }

    @GetMapping("/page")
    public PageResponse<IndisponibiliteVehiculeResponse> findPage(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var result = getAllIndisponibilitesVehiculeUseCase.executePage(vehiculeId, page, size)
                .map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public IndisponibiliteVehiculeResponse findById(@PathVariable Long id) {
        return mapper.toResponse(getIndisponibiliteVehiculeByIdUseCase.execute(id));
    }

    @PutMapping("/{id}")
    public IndisponibiliteVehiculeResponse update(@PathVariable Long id,
                                                  @Valid @RequestBody IndisponibiliteVehiculeRequest request) {
        IndisponibiliteVehicule updated = updateIndisponibiliteVehiculeUseCase.execute(id, mapper.toDomain(request));
        return mapper.toResponse(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteIndisponibiliteVehiculeUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/terminer")
    public IndisponibiliteVehiculeResponse terminer(@PathVariable Long id) {
        return mapper.toResponse(terminerIndisponibiliteVehiculeUseCase.execute(id));
    }
}
