package com.tmk.vtcmanager.interfaces.rest.recette;

import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.usecases.recette.AnnulerLigneRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.recette.ConfirmerVersementUseCase;
import com.tmk.vtcmanager.application.usecases.recette.CreateEncaissementUseCase;
import com.tmk.vtcmanager.application.usecases.recette.GenererLignesRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.recette.GetLignesRecetteUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.request.EncaissementRequest;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.EncaissementResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.LigneRecetteResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.mapper.RecetteRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/recettes/lignes")
@RequiredArgsConstructor
public class LigneRecetteController {

    private final GetLignesRecetteUseCase getLignesRecetteUseCase;
    private final CreateEncaissementUseCase createEncaissementUseCase;
    private final AnnulerLigneRecetteUseCase annulerLigneRecetteUseCase;
    private final ConfirmerVersementUseCase confirmerVersementUseCase;
    private final GenererLignesRecetteUseCase genererLignesRecetteUseCase;
    private final RecetteRestMapper mapper;

    @GetMapping
    public List<LigneRecetteResponse> getLignes(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) StatutLigneRecette statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        LigneRecetteFiltres filtres = LigneRecetteFiltres.builder()
                .vehiculeId(vehiculeId)
                .chauffeurId(chauffeurId)
                .statut(statut)
                .dateDebut(dateDebut)
                .dateFin(dateFin)
                .build();
        return mapper.toResponseList(getLignesRecetteUseCase.findByCriteres(filtres));
    }

    @GetMapping("/page")
    public PageResponse<LigneRecetteResponse> getLignesPage(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) StatutLigneRecette statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        LigneRecetteFiltres filtres = LigneRecetteFiltres.builder()
                .vehiculeId(vehiculeId)
                .chauffeurId(chauffeurId)
                .statut(statut)
                .dateDebut(dateDebut)
                .dateFin(dateFin)
                .build();
        var result = getLignesRecetteUseCase.findPageByCriteres(filtres, page, size)
                .map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public LigneRecetteResponse getLigneById(@PathVariable Long id) {
        return mapper.toResponse(getLignesRecetteUseCase.findById(id));
    }

    @PostMapping("/{id}/encaissements")
    @ResponseStatus(HttpStatus.CREATED)
    public EncaissementResponse createEncaissement(
            @PathVariable Long id,
            @Valid @RequestBody EncaissementRequest request) {
        return mapper.toResponse(createEncaissementUseCase.executer(id, mapper.toDomain(request)));
    }

    @GetMapping("/{id}/encaissements")
    public List<EncaissementResponse> getEncaissements(@PathVariable Long id) {
        LigneRecette ligne = getLignesRecetteUseCase.findById(id);
        return mapper.toEncaissementResponseList(ligne.getEncaissements());
    }

    @PatchMapping("/{id}/annuler")
    public LigneRecetteResponse annuler(@PathVariable Long id) {
        return mapper.toResponse(annulerLigneRecetteUseCase.executer(id));
    }

    @PatchMapping("/{id}/confirmer-versement")
    public LigneRecetteResponse confirmerVersement(@PathVariable Long id) {
        return mapper.toResponse(confirmerVersementUseCase.executer(id));
    }

    @PostMapping("/generer")
    @ResponseStatus(HttpStatus.CREATED)
    public List<LigneRecetteResponse> generer(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        // Principe : sans date, la génération concerne la veille (J-1).
        return mapper.toResponseList(genererLignesRecetteUseCase.executer(
                date != null ? date : LocalDate.now().minusDays(1)));
    }
}
