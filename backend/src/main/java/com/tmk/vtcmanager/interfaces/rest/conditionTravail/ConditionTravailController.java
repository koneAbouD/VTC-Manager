package com.tmk.vtcmanager.interfaces.rest.conditionTravail;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.usecases.conditionTravail.CreateConditionTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionTravailImpactUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.DeleteConditionTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionTravailByIdUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.GetConditionsTravailUseCase;
import com.tmk.vtcmanager.application.usecases.conditionTravail.UpdateConditionTravailUseCase;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.request.CreateConditionTravailRequest;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response.ConditionTravailResponse;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response.SanctionTypeResponse;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.mapper.ConditionTravailRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/conditions-travail")
@RequiredArgsConstructor
public class ConditionTravailController {

    private final GetConditionsTravailUseCase getConditionsTravailUseCase;
    private final GetConditionTravailByIdUseCase getConditionTravailByIdUseCase;
    private final CreateConditionTravailUseCase createConditionTravailUseCase;
    private final UpdateConditionTravailUseCase updateConditionTravailUseCase;
    private final DeleteConditionTravailUseCase deleteConditionTravailUseCase;
    private final GetConditionTravailImpactUseCase getConditionTravailImpactUseCase;
    private final ConditionTravailRestMapper mapper;

    /** Impact d'une modification : véhicules concernés + indisponibilités actives. */
    public record ImpactResponse(int vehicules, int indisponibilites) {}

    @GetMapping("/{id}/impact")
    public ImpactResponse impact(@PathVariable Long id) {
        var impact = getConditionTravailImpactUseCase.execute(id);
        return new ImpactResponse(impact.vehicules(), impact.indisponibilites());
    }

    @GetMapping("/sanctions/types")
    public List<SanctionTypeResponse> getSanctionTypes() {
        return java.util.Arrays.stream(TypeSanction.values())
                .map(t -> new SanctionTypeResponse(t.name(), t.label, t.paramType.name()))
                .toList();
    }

    @GetMapping
    public List<ConditionTravailResponse> getAll() {
        return mapper.toResponseList(getConditionsTravailUseCase.execute());
    }

    @GetMapping("/{id}")
    public ConditionTravailResponse getById(@PathVariable Long id) {
        return mapper.toResponse(getConditionTravailByIdUseCase.execute(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ConditionTravailResponse create(@Valid @RequestBody CreateConditionTravailRequest request) {
        ConditionTravail conditionTravail = createConditionTravailUseCase.execute(mapper.toDomain(request));
        return mapper.toResponse(conditionTravail);
    }

    @PutMapping("/{id}")
    public ConditionTravailResponse update(
            @PathVariable Long id,
            @Valid @RequestBody CreateConditionTravailRequest request) {
        ConditionTravail conditionTravail = updateConditionTravailUseCase.execute(id, mapper.toDomain(request));
        return mapper.toResponse(conditionTravail);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        deleteConditionTravailUseCase.execute(id);
    }
}
