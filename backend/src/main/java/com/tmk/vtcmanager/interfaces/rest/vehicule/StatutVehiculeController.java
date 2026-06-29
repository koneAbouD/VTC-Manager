package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetAllStatutsVehiculeUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.StatutVehiculeResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.StatutVehiculeRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/statuts-vehicule")
@RequiredArgsConstructor
@Tag(name = "Statuts de Véhicule", description = "API pour la consultation des statuts de véhicule (libellé, signification, couleur)")
public class StatutVehiculeController {

    private final GetAllStatutsVehiculeUseCase getAllStatutsVehiculeUseCase;
    private final StatutVehiculeRestMapper statutVehiculeRestMapper;

    @GetMapping
    @Operation(summary = "Lister tous les statuts de véhicule")
    public ResponseEntity<List<StatutVehiculeResponse>> getAllStatutsVehicule() {
        return ResponseEntity.ok(statutVehiculeRestMapper.toResponseList(getAllStatutsVehiculeUseCase.execute()));
    }
}
