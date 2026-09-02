package com.tmk.vtcmanager.interfaces.rest.reaffectation;

import com.tmk.vtcmanager.application.usecases.reaffectation.GetConflitsChauffeurUseCase;
import com.tmk.vtcmanager.interfaces.rest.reaffectation.dto.ConflitChauffeurResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

/** Contrôles de cohérence des créances générées. */
@RestController
@RequestMapping("/api/coherence")
@RequiredArgsConstructor
@Tag(name = "Cohérence", description = "Anomalies relevées sur les créances générées")
public class CoherenceController {

    private final GetConflitsChauffeurUseCase getConflitsChauffeurUseCase;

    /**
     * Journées où un chauffeur porte des créances sur plusieurs véhicules. La
     * génération ne bloque pas ce cas — une recette non créée serait de l'argent
     * que personne ne réclame — mais l'écran doit pouvoir le rappeler tant que
     * rien n'a été tranché.
     */
    @GetMapping("/conflits-chauffeur")
    @Operation(summary = "Chauffeurs affectés à plusieurs véhicules le même jour")
    public List<ConflitChauffeurResponse> conflitsChauffeur(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        return getConflitsChauffeurUseCase.executer(dateDebut, dateFin).stream()
                .map(ConflitChauffeurResponse::de)
                .toList();
    }
}
