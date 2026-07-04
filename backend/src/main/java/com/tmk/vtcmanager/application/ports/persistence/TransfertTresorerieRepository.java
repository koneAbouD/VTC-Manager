package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.tresorerie.TransfertTresorerie;

import java.util.List;

public interface TransfertTresorerieRepository {

    TransfertTresorerie save(TransfertTresorerie transfert);

    List<TransfertTresorerie> findAllOrderByDateDesc();
}
