package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;

import java.util.List;
import java.util.Optional;

public interface ConditionTravailRepository {
    List<ConditionTravail> findAll();
    Optional<ConditionTravail> findById(Long id);
    Optional<ConditionTravail> findByVehiculeId(Long vehiculeId);
    ConditionTravail save(ConditionTravail conditionTravail);
    void deleteById(Long id);
}
