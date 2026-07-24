package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Balise;
import com.tmk.vtcmanager.application.ports.persistence.BaliseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetAllBalisesUseCase {

    private final BaliseRepository baliseRepository;

    public List<Balise> execute() {
        return baliseRepository.findAll();
    }
}
