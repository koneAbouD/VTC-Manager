package com.tmk.vtcmanager.application.usecases.parametre;

import com.tmk.vtcmanager.application.domain.parametre.ParametreGeneral;
import com.tmk.vtcmanager.application.ports.persistence.ParametreGeneralRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetParametresUseCase {

    private final ParametreGeneralRepository repository;

    public List<ParametreGeneral> executer() {
        return repository.findAll();
    }
}
