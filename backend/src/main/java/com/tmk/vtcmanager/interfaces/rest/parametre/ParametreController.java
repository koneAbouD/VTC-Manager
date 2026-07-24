package com.tmk.vtcmanager.interfaces.rest.parametre;

import com.tmk.vtcmanager.application.domain.parametre.ParametreGeneral;
import com.tmk.vtcmanager.application.usecases.parametre.GetParametresUseCase;
import com.tmk.vtcmanager.application.usecases.parametre.UpdateParametreUseCase;
import com.tmk.vtcmanager.interfaces.rest.parametre.dto.ParametreResponse;
import com.tmk.vtcmanager.interfaces.rest.parametre.dto.UpdateParametreRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** Réglages globaux de l'application (paramètres clé-valeur). */
@RestController
@RequestMapping("/api/parametres")
@RequiredArgsConstructor
public class ParametreController {

    private final GetParametresUseCase getParametresUseCase;
    private final UpdateParametreUseCase updateParametreUseCase;

    @GetMapping
    public List<ParametreResponse> getAll() {
        return getParametresUseCase.executer().stream().map(this::toResponse).toList();
    }

    @PutMapping("/{cle}")
    public ParametreResponse update(@PathVariable String cle,
                                    @Valid @RequestBody UpdateParametreRequest request) {
        return toResponse(updateParametreUseCase.executer(cle, request.valeur()));
    }

    private ParametreResponse toResponse(ParametreGeneral p) {
        return new ParametreResponse(p.getCle(), p.getValeur(), p.getLibelle(), p.getDescription());
    }
}
