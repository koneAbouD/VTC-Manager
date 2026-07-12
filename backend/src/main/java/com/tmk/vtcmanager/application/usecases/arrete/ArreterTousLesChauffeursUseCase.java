package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.finance.CompteCourant;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Arrête en lot le compte de tous les chauffeurs disposant d'un fonds de
 * cotisation sur la période (restitution mensuelle groupée). Chaque chauffeur
 * est arrêté dans sa propre transaction (le use case injecté est proxifié) ;
 * un échec isolé n'interrompt pas le lot et ne compromet pas les autres.
 */
@Slf4j
@RequiredArgsConstructor
public class ArreterTousLesChauffeursUseCase {

    private final CompteCourantRepository compteCourantRepository;
    private final ArreterCompteUseCase arreterCompteUseCase;

    public List<ArreteCompte> executer(LocalDate periodeDebut, LocalDate periodeFin,
                                       LocalDate dateArrete, ModePaiement modePaiement,
                                       Long compteTresorerieId) {
        List<ArreteCompte> arretes = new ArrayList<>();
        for (CompteCourant compte : compteCourantRepository.getComptesCourantsParChauffeur()) {
            if (compte.getFondsCotisation() == null || compte.getFondsCotisation().signum() <= 0) {
                continue; // rien à restituer
            }
            try {
                arretes.add(arreterCompteUseCase.executer(
                        PerimetreArrete.CHAUFFEUR, compte.getTiersId(),
                        periodeDebut, periodeFin, dateArrete, modePaiement, compteTresorerieId));
            } catch (RuntimeException e) {
                log.warn("Arrêté en lot ignoré pour le chauffeur {} : {}",
                        compte.getTiersId(), e.getMessage());
            }
        }
        return arretes;
    }
}
