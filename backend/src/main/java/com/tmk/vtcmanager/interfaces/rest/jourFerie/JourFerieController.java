package com.tmk.vtcmanager.interfaces.rest.jourFerie;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;
import com.tmk.vtcmanager.application.domain.jourFerie.TypeJourFerie;
import com.tmk.vtcmanager.application.usecases.jourFerie.CreateJourFerieUseCase;
import com.tmk.vtcmanager.application.usecases.jourFerie.DeleteJourFerieUseCase;
import com.tmk.vtcmanager.application.usecases.jourFerie.GetJoursFeriesUseCase;
import com.tmk.vtcmanager.application.usecases.jourFerie.SeedJoursFeriesUseCase;
import com.tmk.vtcmanager.interfaces.rest.jourFerie.dto.request.JourFerieRequest;
import com.tmk.vtcmanager.interfaces.rest.jourFerie.dto.response.JourFerieResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
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
@RequestMapping("/api/jours-feries")
@RequiredArgsConstructor
public class JourFerieController {

    private final GetJoursFeriesUseCase getJoursFeriesUseCase;
    private final CreateJourFerieUseCase createJourFerieUseCase;
    private final DeleteJourFerieUseCase deleteJourFerieUseCase;
    private final SeedJoursFeriesUseCase seedJoursFeriesUseCase;

    /** Jours fériés d'une année (défaut : année courante). */
    @GetMapping
    public List<JourFerieResponse> getByAnnee(@RequestParam(required = false) Integer annee) {
        int cible = annee != null ? annee : LocalDate.now().getYear();
        return getJoursFeriesUseCase.execute(cible).stream().map(this::toResponse).toList();
    }

    /** Ajout/confirmation manuelle (fêtes musulmanes, décrets). */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public JourFerieResponse create(@Valid @RequestBody JourFerieRequest request) {
        JourFerie jourFerie = JourFerie.builder()
                .date(request.date())
                .libelle(request.libelle())
                .type(resolveType(request.type()))
                .build();
        return toResponse(createJourFerieUseCase.execute(jourFerie));
    }

    /** Génère les fériés déterministes (fixes + chrétiens) de l'année. */
    @PostMapping("/seed")
    @ResponseStatus(HttpStatus.CREATED)
    public List<JourFerieResponse> seed(@RequestParam int annee) {
        return seedJoursFeriesUseCase.execute(annee).stream().map(this::toResponse).toList();
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        deleteJourFerieUseCase.execute(id);
    }

    private TypeJourFerie resolveType(String type) {
        if (type == null || type.isBlank()) {
            return TypeJourFerie.MUSULMAN;
        }
        try {
            return TypeJourFerie.valueOf(type);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Type de jour férié invalide : " + type);
        }
    }

    private JourFerieResponse toResponse(JourFerie j) {
        return new JourFerieResponse(
                j.getId(),
                j.getDate(),
                j.getLibelle(),
                j.getType() != null ? j.getType().name() : null,
                j.getAnnee(),
                j.getSource() != null ? j.getSource().name() : null);
    }
}
