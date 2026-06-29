package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.StatutVehicule;

import java.util.List;
import java.util.Optional;

public interface StatutVehiculeRepository {

    List<StatutVehicule> findAll();

    Optional<StatutVehicule> findByCode(String code);
}
