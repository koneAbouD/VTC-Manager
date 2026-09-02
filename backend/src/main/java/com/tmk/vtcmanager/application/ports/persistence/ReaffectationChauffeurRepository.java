package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.reaffectation.ReaffectationChauffeur;

import java.util.List;

/** Journal des changements de débiteur sur les créances. */
public interface ReaffectationChauffeurRepository {

    ReaffectationChauffeur save(ReaffectationChauffeur reaffectation);

    /** Historique d'une ligne, de la plus récente à la plus ancienne. */
    List<ReaffectationChauffeur> findByDocument(TypeDocumentCreance document, Long documentId);
}
