package com.tmk.vtcmanager.interfaces.rest.etatparc;

import com.tmk.vtcmanager.application.usecases.etatparc.GetEtatParcUseCase;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcSummaryResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/etat-parc")
@RequiredArgsConstructor
public class EtatParcController {

    private final GetEtatParcUseCase getEtatParcUseCase;

    @GetMapping("/summary")
    public EtatParcSummaryResponse summary(
            @RequestParam(required = false) Long groupeId,
            @RequestParam(required = false) Long activiteId) {
        return getEtatParcUseCase.execute(groupeId, activiteId);
    }
}
