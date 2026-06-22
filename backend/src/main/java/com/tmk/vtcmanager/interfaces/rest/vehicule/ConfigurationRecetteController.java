package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.usecases.configurationRecette.CreateConfigurationRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.configurationRecette.GetConfigurationRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.configurationRecette.UpdateConfigurationRecetteUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.ConfigurationRecetteRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ConfigurationRecetteResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.ConfigurationRecetteRestMapper;
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
@RequestMapping("/api/vehicules/{vehiculeId}/configuration-recette")
@RequiredArgsConstructor
public class ConfigurationRecetteController {

    private final GetConfigurationRecetteUseCase getConfigurationRecetteUseCase;
    private final CreateConfigurationRecetteUseCase createConfigurationRecetteUseCase;
    private final UpdateConfigurationRecetteUseCase updateConfigurationRecetteUseCase;
    private final ConfigurationRecetteRestMapper mapper;

    @GetMapping
    public ConfigurationRecetteResponse getConfiguration(@PathVariable Long vehiculeId) {
        return mapper.toResponse(getConfigurationRecetteUseCase.execute(vehiculeId));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ConfigurationRecetteResponse createConfiguration(
            @PathVariable Long vehiculeId,
            @Valid @RequestBody ConfigurationRecetteRequest request) {
        ConfigurationRecette configurationRecette = createConfigurationRecetteUseCase.execute(
                vehiculeId,
                mapper.toDomain(request)
        );
        return mapper.toResponse(configurationRecette);
    }

    @PutMapping
    public ConfigurationRecetteResponse updateConfiguration(
            @PathVariable Long vehiculeId,
            @Valid @RequestBody ConfigurationRecetteRequest request) {
        ConfigurationRecette configurationRecette = updateConfigurationRecetteUseCase.execute(
                vehiculeId,
                mapper.toDomain(request)
        );
        return mapper.toResponse(configurationRecette);
    }
}
