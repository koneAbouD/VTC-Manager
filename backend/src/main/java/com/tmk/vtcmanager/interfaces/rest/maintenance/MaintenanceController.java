package com.tmk.vtcmanager.interfaces.rest.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.usecases.maintenance.CompleteMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.maintenance.DeleteMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.maintenance.GetAllMaintenancesUseCase;
import com.tmk.vtcmanager.application.usecases.maintenance.GetMaintenanceByIdUseCase;
import com.tmk.vtcmanager.application.usecases.maintenance.GetMaintenanceTotalCostByVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.maintenance.GetUpcomingMaintenancesUseCase;
import com.tmk.vtcmanager.application.usecases.maintenance.ScheduleMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.maintenance.UpdateMaintenanceUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.maintenance.dto.request.CompleteMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.maintenance.dto.request.MaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.maintenance.dto.response.MaintenanceResponse;
import com.tmk.vtcmanager.interfaces.rest.maintenance.mapper.MaintenanceRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/maintenances")
@RequiredArgsConstructor
public class MaintenanceController {

    private final ScheduleMaintenanceUseCase scheduleMaintenanceUseCase;
    private final UpdateMaintenanceUseCase updateMaintenanceUseCase;
    private final DeleteMaintenanceUseCase deleteMaintenanceUseCase;
    private final GetMaintenanceByIdUseCase getMaintenanceByIdUseCase;
    private final GetAllMaintenancesUseCase getAllMaintenancesUseCase;
    private final CompleteMaintenanceUseCase completeMaintenanceUseCase;
    private final GetUpcomingMaintenancesUseCase getUpcomingMaintenancesUseCase;
    private final GetMaintenanceTotalCostByVehiculeUseCase getMaintenanceTotalCostByVehiculeUseCase;
    private final MaintenanceRestMapper mapper;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MaintenanceResponse schedule(@Valid @RequestBody MaintenanceRequest request) {
        Maintenance created = scheduleMaintenanceUseCase.execute(request.vehiculeId(), mapper.toDomain(request));
        return mapper.toResponse(created);
    }

    @GetMapping
    public List<MaintenanceResponse> findAll(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) LocalDate dateDebut,
            @RequestParam(required = false) LocalDate dateFin,
            @RequestParam(required = false) MaintenanceStatus statut) {
        return mapper.toResponseList(getAllMaintenancesUseCase.execute(vehiculeId, dateDebut, dateFin, statut));
    }

    @GetMapping("/page")
    public PageResponse<MaintenanceResponse> findPage(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) LocalDate dateDebut,
            @RequestParam(required = false) LocalDate dateFin,
            @RequestParam(required = false) MaintenanceStatus statut,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var result = getAllMaintenancesUseCase
                .executePage(vehiculeId, dateDebut, dateFin, statut, page, size)
                .map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public MaintenanceResponse findById(@PathVariable Long id) {
        return mapper.toResponse(getMaintenanceByIdUseCase.execute(id));
    }

    @PutMapping("/{id}")
    public MaintenanceResponse update(@PathVariable Long id, @Valid @RequestBody MaintenanceRequest request) {
        Maintenance updated = updateMaintenanceUseCase.execute(id, mapper.toDomain(request));
        return mapper.toResponse(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteMaintenanceUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/complete")
    public MaintenanceResponse complete(@PathVariable Long id, @RequestBody CompleteMaintenanceRequest request) {
        return mapper.toResponse(
                completeMaintenanceUseCase.execute(id, request.cout(), request.dateEffectueeOrToday(),
                        request.modePaiementOrDefault(), request.categorieId(), request.sousCategorieId())
        );
    }

    @GetMapping("/upcoming")
    public List<MaintenanceResponse> upcoming(@RequestParam(defaultValue = "7") int joursAvant) {
        return mapper.toResponseList(getUpcomingMaintenancesUseCase.execute(joursAvant));
    }

    @GetMapping("/total-cost")
    public Map<String, BigDecimal> totalCost(@RequestParam Long vehiculeId) {
        return Map.of("total", getMaintenanceTotalCostByVehiculeUseCase.execute(vehiculeId));
    }
}
