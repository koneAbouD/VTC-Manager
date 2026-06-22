package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetAllTypesActivitesUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.TypeActiviteResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.TypeActiviteRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/types-activites")
@RequiredArgsConstructor
@Tag(name = "Types d'Activité", description = "API pour la gestion des types d'activité")
public class TypeActiviteController {

    private final GetAllTypesActivitesUseCase getAllTypesActivitesUseCase;
    private final TypeActiviteRestMapper typeActiviteRestMapper;

    @GetMapping
    @Operation(summary = "Lister tous les types d'activité")
    public ResponseEntity<List<TypeActiviteResponse>> getAllTypesActivites() {
        return ResponseEntity.ok(typeActiviteRestMapper.toResponseList(getAllTypesActivitesUseCase.execute()));
    }
}