package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.finance.CompteCourant;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Optional;

/** Consultation des arrêtés de compte (historique + détail). */
@RequiredArgsConstructor
public class GetArreteUseCase {

    private final ArreteCompteRepository arreteCompteRepository;
    private final CompteCourantRepository compteCourantRepository;

    public List<ArreteCompte> lister() {
        return lister(null, null);
    }

    /**
     * Historique filtré sur la date d'arrêté : un mois précis (annee + mois),
     * une année entière (annee seule) ou tout l'historique (annee nulle).
     */
    public List<ArreteCompte> lister(Integer annee, Integer mois) {
        if (annee == null) {
            if (mois != null) {
                throw new IllegalArgumentException("Le filtre par mois exige aussi l'année");
            }
            return arreteCompteRepository.findAll(null, null);
        }
        if (mois == null) {
            return arreteCompteRepository.findAll(LocalDate.of(annee, 1, 1), LocalDate.of(annee, 12, 31));
        }
        if (mois < 1 || mois > 12) {
            throw new IllegalArgumentException("Mois invalide : " + mois);
        }
        YearMonth periode = YearMonth.of(annee, mois);
        return arreteCompteRepository.findAll(periode.atDay(1), periode.atEndOfMonth());
    }

    /** Relevé de compte d'un chauffeur : tous les arrêtés où il est bénéficiaire. */
    public List<ArreteCompte> parBeneficiaire(Long chauffeurId) {
        return arreteCompteRepository.findByBeneficiaire(chauffeurId);
    }

    /** Détail enrichi du reste à restituer/dû (solde de compte courant courant du périmètre). */
    public Optional<ArreteCompte> detail(Long id) {
        return arreteCompteRepository.findById(id).map(this::enrichirReste);
    }

    private ArreteCompte enrichirReste(ArreteCompte arrete) {
        List<CompteCourant> comptes = arrete.getPerimetre() == PerimetreArrete.VEHICULE
                ? compteCourantRepository.getComptesCourantsParVehicule()
                : compteCourantRepository.getComptesCourantsParChauffeur();
        BigDecimal reste = comptes.stream()
                .filter(c -> arrete.getPerimetreId().equals(c.getTiersId()))
                .map(CompteCourant::getNet)
                .findFirst()
                .orElse(BigDecimal.ZERO);
        arrete.setResteNet(reste);
        return arrete;
    }
}
