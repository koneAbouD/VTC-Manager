package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;
import java.util.Optional;

/** Consultation des arrêtés de compte (historique + détail). */
@RequiredArgsConstructor
public class GetArreteUseCase {

    private final ArreteCompteRepository arreteCompteRepository;

    public List<ArreteCompte> lister() {
        return arreteCompteRepository.findAll();
    }

    /** Relevé de compte d'un chauffeur : tous les arrêtés où il est bénéficiaire. */
    public List<ArreteCompte> parBeneficiaire(Long chauffeurId) {
        return arreteCompteRepository.findByBeneficiaire(chauffeurId);
    }

    public Optional<ArreteCompte> detail(Long id) {
        return arreteCompteRepository.findById(id);
    }
}
