package com.tmk.vtcmanager.interfaces.rest.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.usecases.indisponibilite.CreateIndisponibiliteUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibilite.DeleteIndisponibiliteUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibilite.GetAllIndisponibilitesUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibilite.GetIndisponibiliteByIdUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibilite.TerminerIndisponibiliteUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibilite.UpdateIndisponibiliteUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.indisponibilite.dto.request.IndisponibiliteRequest;
import com.tmk.vtcmanager.interfaces.rest.indisponibilite.dto.response.IndisponibiliteResponse;
import com.tmk.vtcmanager.interfaces.rest.indisponibilite.mapper.IndisponibiliteRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/indisponibilites")
@RequiredArgsConstructor
public class IndisponibiliteController {

    private final CreateIndisponibiliteUseCase createIndisponibiliteUseCase;
    private final UpdateIndisponibiliteUseCase updateIndisponibiliteUseCase;
    private final DeleteIndisponibiliteUseCase deleteIndisponibiliteUseCase;
    private final GetIndisponibiliteByIdUseCase getIndisponibiliteByIdUseCase;
    private final GetAllIndisponibilitesUseCase getAllIndisponibilitesUseCase;
    private final TerminerIndisponibiliteUseCase terminerIndisponibiliteUseCase;
    private final IndisponibiliteRestMapper mapper;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public IndisponibiliteResponse create(@Valid @RequestBody IndisponibiliteRequest request) {
        Indisponibilite created = createIndisponibiliteUseCase.execute(mapper.toDomain(request));
        return mapper.toResponse(created);
    }

    @GetMapping
    public List<IndisponibiliteResponse> findAll(@RequestParam(required = false) Long chauffeurId) {
        return mapper.toResponseList(getAllIndisponibilitesUseCase.execute(chauffeurId));
    }

    @GetMapping("/page")
    public PageResponse<IndisponibiliteResponse> findPage(
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var result = getAllIndisponibilitesUseCase.executePage(chauffeurId, page, size)
                .map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public IndisponibiliteResponse findById(@PathVariable Long id) {
        return mapper.toResponse(getIndisponibiliteByIdUseCase.execute(id));
    }

    @PutMapping("/{id}")
    public IndisponibiliteResponse update(@PathVariable Long id, @Valid @RequestBody IndisponibiliteRequest request) {
        Indisponibilite updated = updateIndisponibiliteUseCase.execute(id, mapper.toDomain(request));
        return mapper.toResponse(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteIndisponibiliteUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/terminer")
    public IndisponibiliteResponse terminer(@PathVariable Long id) {
        return mapper.toResponse(terminerIndisponibiliteUseCase.execute(id));
    }
}
