package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;

import java.util.List;
import java.util.Optional;

public interface TypeActiviteRepository {

    List<TypeActivite> findAll();

    Optional<TypeActivite> findById(Long id);
}