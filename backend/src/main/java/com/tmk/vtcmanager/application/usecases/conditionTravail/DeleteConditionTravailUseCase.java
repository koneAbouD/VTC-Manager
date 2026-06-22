package com.tmk.vtcmanager.application.usecases.conditionTravail;

import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class DeleteConditionTravailUseCase {

    private final ConditionTravailRepository conditionTravailRepository;

    public void execute(Long id) {
        conditionTravailRepository.deleteById(id);
    }
}
