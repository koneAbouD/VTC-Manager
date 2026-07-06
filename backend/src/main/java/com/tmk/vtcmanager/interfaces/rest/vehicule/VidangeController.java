package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.usecases.vehicule.CreateVidangeUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.GetVidangesByVehiculeUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.VidangeRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VidangeResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.VidangeRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Vidanges d'un véhicule : historique (GET) et enregistrement d'une nouvelle
 * vidange (POST). La plus récente fait office de « dernière vidange » et sa
 * cible de « prochaine vidange » dans l'onglet Infos du véhicule.
 */
@RestController
@RequestMapping("/api/vehicules/{vehiculeId}/vidanges")
@RequiredArgsConstructor
public class VidangeController {

    private final CreateVidangeUseCase createVidangeUseCase;
    private final GetVidangesByVehiculeUseCase getVidangesByVehiculeUseCase;
    private final VidangeRestMapper mapper;

    @GetMapping
    public List<VidangeResponse> findByVehicule(@PathVariable Long vehiculeId) {
        return mapper.toResponseList(getVidangesByVehiculeUseCase.execute(vehiculeId));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public VidangeResponse create(@PathVariable Long vehiculeId,
                                  @Valid @RequestBody VidangeRequest request) {
        Vidange created = createVidangeUseCase.execute(vehiculeId, mapper.toDomain(request));
        return mapper.toResponse(created);
    }
}
