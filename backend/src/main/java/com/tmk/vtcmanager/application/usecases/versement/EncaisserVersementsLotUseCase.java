package com.tmk.vtcmanager.application.usecases.versement;

import com.tmk.vtcmanager.application.domain.versement.ResultatVersementLot;
import com.tmk.vtcmanager.application.domain.versement.SaisieVersement;
import com.tmk.vtcmanager.application.domain.versement.VersementEnregistre;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.util.ArrayList;
import java.util.List;

/**
 * Encaissement de masse par versements : plusieurs journées soldées d'un coup,
 * chacune avec sa cotisation du même jour.
 *
 * <p><b>Deux niveaux de transaction, volontairement.</b> Chaque versement est
 * atomique — sa recette et sa cotisation passent ensemble ou pas du tout —
 * parce qu'il appelle {@link EncaisserVersementUseCase} par son proxy. Le lot,
 * lui, n'a pas de transaction englobante : un refus ne vaut que pour le
 * versement visé, l'argent des autres a bien été reçu.
 */
@Slf4j
@RequiredArgsConstructor
public class EncaisserVersementsLotUseCase {

    private final EncaisserVersementUseCase encaisserVersementUseCase;

    public List<ResultatVersementLot> executer(List<SaisieVersement> versements) {
        List<ResultatVersementLot> resultats = new ArrayList<>();

        for (SaisieVersement saisie : versements) {
            try {
                VersementEnregistre enregistre = encaisserVersementUseCase.executer(saisie);
                resultats.add(ResultatVersementLot.reussi(saisie, enregistre.versementId()));
            } catch (RuntimeException e) {
                // Le message des exceptions métier est déjà rédigé pour l'écran ;
                // pour le reste, on ne remonte pas une trace technique au guichet.
                log.warn("Versement refusé dans le lot (recette {}, cotisation {}) : {}",
                        saisie.recette() == null ? null : saisie.recette().ligneId(),
                        saisie.cotisation() == null ? null : saisie.cotisation().ligneId(),
                        e.toString());
                resultats.add(ResultatVersementLot.echec(saisie, messageLisible(e)));
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
}
