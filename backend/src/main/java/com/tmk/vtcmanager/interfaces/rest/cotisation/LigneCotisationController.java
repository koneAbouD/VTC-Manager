package com.tmk.vtcmanager.interfaces.rest.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.usecases.cotisation.AnnulerLigneCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.CreateEncaissementCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.GenererLignesCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.GetLignesCotisationUseCase;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.request.EncaissementCotisationRequest;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.EncaissementCotisationResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.LigneCotisationResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.mapper.CotisationRestMapper;
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
@RequestMapping("/api/cotisations/lignes")
@RequiredArgsConstructor
public class LigneCotisationController {

    private final GetLignesCotisationUseCase getLignesCotisationUseCase;
    private final CreateEncaissementCotisationUseCase createEncaissementUseCase;
    private final AnnulerLigneCotisationUseCase annulerUseCase;
    private final GenererLignesCotisationUseCase genererUseCase;
    private final CotisationRestMapper mapper;

    @GetMapping
    public List<LigneCotisationResponse> getLignes(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) StatutLigneCotisation statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        return mapper.toResponseList(getLignesCotisationUseCase.findByCriteres(
                LigneCotisationFiltres.builder()
                        .vehiculeId(vehiculeId).chauffeurId(chauffeurId)
                        .statut(statut).dateDebut(dateDebut).dateFin(dateFin)
                        .build()));
    }

    @GetMapping("/{id}")
    public LigneCotisationResponse getLigneById(@PathVariable Long id) {
        return mapper.toResponse(getLignesCotisationUseCase.findById(id));
    }

    @PostMapping("/{id}/encaissements")
    @ResponseStatus(HttpStatus.CREATED)
    public EncaissementCotisationResponse createEncaissement(
            @PathVariable Long id,
            @Valid @RequestBody EncaissementCotisationRequest request) {
        return mapper.toResponse(createEncaissementUseCase.executer(id, mapper.toDomain(request)));
    }

    @GetMapping("/{id}/encaissements")
    public List<EncaissementCotisationResponse> getEncaissements(@PathVariable Long id) {
        return mapper.toEncaissementResponseList(getLignesCotisationUseCase.findById(id).getEncaissements());
    }

    @PatchMapping("/{id}/annuler")
    public LigneCotisationResponse annuler(@PathVariable Long id) {
        return mapper.toResponse(annulerUseCase.executer(id));
    }

    @PostMapping("/generer")
    @ResponseStatus(HttpStatus.CREATED)
    public List<LigneCotisationResponse> generer(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return mapper.toResponseList(genererUseCase.executer(date != null ? date : LocalDate.now()));
    }
}
