package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.encaissement.MontantParLigne;
import com.tmk.vtcmanager.application.domain.encaissement.ResultatEncaissementLot;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Encaisse plusieurs lignes de recette d'un même geste de caisse : le chauffeur
 * verse une fois pour plusieurs journées, le guichet ne saisit qu'une fois le
 * mode, la date et le commentaire.
 *
 * <p><b>Sans transaction englobante, volontairement.</b> Chaque ligne garde la
 * sienne, ouverte par {@link CreateEncaissementUseCase}. Un refus — période
 * comptable clôturée, caisse du jour déjà comptée, mode de paiement que la
 * configuration du véhicule n'autorise pas — ne vaut que pour la ligne visée :
 * l'argent des autres a bien été reçu, et tout annuler obligerait à ressaisir
 * l'ensemble pour une seule créance fautive. Le lot rend donc un verdict par
 * ligne, à charge pour l'appelant de dire ce qui est passé.
 *
 * <p>Les notifications restent celles du cas unitaire : le service qui les
 * émet regroupe déjà les encaissements d'un même chauffeur au même jour, si
 * bien qu'un lot ne fait sonner qu'une fois le téléphone du chauffeur.
 */
@Slf4j
@RequiredArgsConstructor
public class CreateEncaissementsLotUseCase {

    private final CreateEncaissementUseCase createEncaissementUseCase;

    public List<ResultatEncaissementLot> executer(List<MontantParLigne> lignes,
                                                  ModePaiement modeEncaissement,
                                                  LocalDate dateEncaissement,
                                                  String reference,
                                                  String commentaire) {
        List<ResultatEncaissementLot> resultats = new ArrayList<>();

        for (MontantParLigne ligne : lignes) {
            try {
                Encaissement encaissement = Encaissement.builder()
                        .ligneRecetteId(ligne.ligneId())
                        .montant(ligne.montant())
                        .modeEncaissement(modeEncaissement)
                        .dateEncaissement(dateEncaissement)
                        .reference(reference)
                        .commentaire(commentaire)
                        .build();

                Encaissement saved = createEncaissementUseCase.executer(ligne.ligneId(), encaissement);
                resultats.add(ResultatEncaissementLot.reussi(ligne.ligneId(), saved.getId()));
            } catch (RuntimeException e) {
                // Le message des exceptions métier est déjà rédigé pour l'écran ;
                // pour le reste, on ne remonte pas une trace technique au guichet.
                log.warn("Encaissement en lot refusé sur la ligne de recette {} : {}",
                        ligne.ligneId(), e.toString());
                resultats.add(ResultatEncaissementLot.echec(ligne.ligneId(), messageLisible(e)));
            }
        }

        return resultats;
    }

    static String messageLisible(RuntimeException e) {
        String message = e.getMessage();
        return (message == null || message.isBlank())
                ? "Encaissement refusé."
                : message;
    }

    /** Somme des montants demandés, pour les journaux et les tests. */
    static BigDecimal total(List<MontantParLigne> lignes) {
        return lignes.stream()
                .map(MontantParLigne::montant)
                .filter(m -> m != null)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
