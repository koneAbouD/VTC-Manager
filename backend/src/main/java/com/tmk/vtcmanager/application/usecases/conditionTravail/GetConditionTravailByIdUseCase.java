package com.tmk.vtcmanager.application.usecases.conditionTravail;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class GetConditionTravailByIdUseCase {

    private final ConditionTravailRepository conditionTravailRepository;

    public ConditionTravail execute(Long id) {
        return conditionTravailRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("ConditionTravail non trouvée avec l'id : " + id));
    }
}
