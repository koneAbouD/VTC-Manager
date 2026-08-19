package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Trésorerie archivée d'un mois clos, compte par compte.
 *
 * <p>C'est la justification de la ligne « trésorerie » de la photo : chaque
 * compte, son solde arrêté au dernier jour du mois, et la date du dernier
 * comptage qui l'atteste. L'écart entre ces deux dates est ce que le lecteur
 * doit voir — la clôture n'exige qu'un comptage quelque part dans le mois, et
 * un solde de fin de mois adossé à un comptage du 3 ne vaut pas celui d'un
 * comptage du 31.
 *
 * <p>Liste vide si le mois n'est pas clos, ou si sa clôture est antérieure à
 * l'archivage des soldes.
 */
@RequiredArgsConstructor
public class GetSoldesClotureUseCase {

    private final EtatsClotureRepository etatsClotureRepository;

    @Transactional(readOnly = true)
    public List<EtatsCloture.SoldeCompteCloture> executer(int annee, int mois) {
        return etatsClotureRepository.findByPeriode(annee, mois)
                .map(EtatsCloture::getSoldes)
                .orElse(List.of());
    }
}
