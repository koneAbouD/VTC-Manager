package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Types d'activité <b>actifs uniquement</b>, triés par nom — destinés à la
 * sélection (formulaires). Le paramétrage consomme la liste complète via
 * {@link GetAllTypesActivitesUseCase}.
 */
@Service
@RequiredArgsConstructor
public class GetActifsTypesActivitesUseCase {

    private final TypeActiviteRepository typeActiviteRepository;

    public List<TypeActivite> execute() {
        return typeActiviteRepository.findAllActifs();
    }
}
