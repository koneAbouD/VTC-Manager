package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetAllTypesActivitesUseCase {

    private final TypeActiviteRepository typeActiviteRepository;

    public List<TypeActivite> execute() {
        return typeActiviteRepository.findAll();
    }
}