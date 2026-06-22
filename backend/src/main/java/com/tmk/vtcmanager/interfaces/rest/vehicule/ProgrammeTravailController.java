package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.usecases.programmeTravail.CreateProgrammeTravailUseCase;
import com.tmk.vtcmanager.application.usecases.programmeTravail.GetProgrammeTravailUseCase;
import com.tmk.vtcmanager.application.usecases.programmeTravail.InvertProgrammeTravailUseCase;
import com.tmk.vtcmanager.application.usecases.programmeTravail.UpdateProgrammeTravailUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.ProgrammeTravailRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ProgrammeTravailResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.ProgrammeTravailRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/vehicules/{vehiculeId}/programme")
@RequiredArgsConstructor
public class ProgrammeTravailController {

    private final GetProgrammeTravailUseCase getProgrammeTravailUseCase;
    private final CreateProgrammeTravailUseCase createProgrammeTravailUseCase;
    private final UpdateProgrammeTravailUseCase updateProgrammeTravailUseCase;
    private final InvertProgrammeTravailUseCase invertProgrammeTravailUseCase;
    private final ProgrammeTravailRestMapper mapper;

    @GetMapping
    public ProgrammeTravailResponse getProgramme(@PathVariable Long vehiculeId) {
        return mapper.toResponse(getProgrammeTravailUseCase.execute(vehiculeId));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProgrammeTravailResponse createProgramme(
            @PathVariable Long vehiculeId,
            @Valid @RequestBody ProgrammeTravailRequest request) {
        ProgrammeTravail programme = createProgrammeTravailUseCase.execute(vehiculeId, mapper.toDomain(request));
        return mapper.toResponse(programme);
    }

    @PutMapping
    public ProgrammeTravailResponse updateProgramme(
            @PathVariable Long vehiculeId,
            @Valid @RequestBody ProgrammeTravailRequest request) {
        ProgrammeTravail programme = updateProgrammeTravailUseCase.execute(vehiculeId, mapper.toDomain(request));
        return mapper.toResponse(programme);
    }

    @PostMapping("/inversion")
    public ProgrammeTravailResponse invertProgramme(@PathVariable Long vehiculeId) {
        return mapper.toResponse(invertProgrammeTravailUseCase.execute(vehiculeId));
    }
}
