package com.tmk.vtcmanager.application.usecases.conditionTravail;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetConditionsTravailUseCase {

    private final ConditionTravailRepository conditionTravailRepository;

    public List<ConditionTravail> execute() {
        return conditionTravailRepository.findAll();
    }
}
