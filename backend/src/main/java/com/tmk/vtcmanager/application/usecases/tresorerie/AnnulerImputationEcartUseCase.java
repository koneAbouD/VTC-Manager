package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.usecases.operationFinanciere.AnnulerOperationFinanciereUseCase;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Retour sur une imputation d'écart de caisse.
 *
 * <p>Trancher un écart n'est pas un geste anodin : la décision fait entrer un
 * manquant dans le résultat, ou en fait une créance sur le responsable du
 * fonds. Elle se prend souvent avant d'avoir tout compris — le manquant du
 * mardi s'explique le jeudi par une recette saisie deux fois. Il faut donc
 * pouvoir y revenir : l'écart redevient à trancher, et l'on décide à nouveau.
 *
 * <p>Les deux écritures produites par l'imputation sont contre-passées, jamais
 * effacées, et <em>à la date du relevé</em> — comme elles avaient été passées.
 * Les extourner au jour de la décision les ferait tomber dans un autre mois que
 * les écritures qu'elles neutralisent : le compte d'attente resterait ouvert
 * d'un côté et le résultat faussé de l'autre, chacun dans son mois.
 *
 * <p>Sert deux fois : à l'utilisateur qui corrige un arbitrage, et au retrait du
 * relevé lui-même, qui commence par défaire l'imputation avant de contre-passer
 * l'ajustement — un écart qui n'existe plus n'a pas à rester tranché.
 */
@RequiredArgsConstructor
public class AnnulerImputationEcartUseCase {

    private final ClotureCaisseRepository clotureCaisseRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final AnnulerOperationFinanciereUseCase annulerOperationUseCase;

    @Transactional
    public ClotureCaisse executer(Long clotureId, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException(
                    "Le motif est obligatoire : il justifie le retour sur l'imputation.");
        }

        ClotureCaisse cloture = clotureCaisseRepository.findById(clotureId)
                .orElseThrow(() -> ResourceNotFoundException.of("Relevé de caisse", clotureId));

        if (!cloture.ecartImpute()) {
            throw new IllegalStateException(
                    "L'écart de ce relevé n'a pas été imputé : il n'y a rien à défaire.");
        }
        // Le mois où les écritures d'imputation sont tombées est publié : les
        // contre-passer changerait un résultat déjà servi.
        periodeClotureeGuard.verifier(cloture.getDateCloture());

        return clotureCaisseRepository.save(defaire(cloture, motif));
    }

    /**
     * Contre-passe les écritures de l'imputation et remet l'écart en attente,
     * sans écrire en base : l'appelant enchaîne parfois d'autres changements sur
     * le même relevé — c'est le cas du retrait, qui l'annule dans la foulée.
     */
    ClotureCaisse defaire(ClotureCaisse cloture, String motif) {
        // Le compte d'attente se rouvre : l'écart n'est plus soldé.
        //
        // Identifiant absent sur les imputations d'avant son enregistrement :
        // l'écriture reste alors au journal, orpheline, et se contre-passe à la
        // main. Bloquer ici enfermerait de nouveau l'utilisateur — ce que ce
        // cas d'usage existe précisément pour éviter.
        if (cloture.getOperationSoldeAttenteId() != null) {
            annulerOperationUseCase.execute(cloture.getOperationSoldeAttenteId(),
                    motif, cloture.getDateCloture());
        }
        // …et l'écart sort du résultat, s'il y était entré : rien à faire quand
        // le responsable devait rembourser, cette décision-là n'ayant produit
        // aucune écriture de résultat.
        if (cloture.getOperationImputationId() != null) {
            annulerOperationUseCase.execute(cloture.getOperationImputationId(),
                    motif, cloture.getDateCloture());
        }

        cloture.retirerImputation();
        return cloture;
    }
}
