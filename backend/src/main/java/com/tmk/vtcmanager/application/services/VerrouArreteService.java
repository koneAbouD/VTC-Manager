package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;

/**
 * Jusqu'où l'on peut revenir sur une annulation.
 *
 * <p>Restaurer, c'est remettre une créance ou une intervention dans un état
 * qu'un arrêté a déjà consigné comme absent. Deux arrêtés ferment la porte :
 * <ul>
 *   <li>la <b>clôture de période</b>, qui fige le mois pour toute
 *       l'entreprise — les états ont été publiés sans cette créance ;</li>
 *   <li>la <b>clôture de caisse</b>, qui arrête une journée : dès qu'une caisse
 *       a été comptée ce jour-là ou après, ce qui datait de ce jour ne bouge
 *       plus.</li>
 * </ul>
 *
 * <p>La même règle sert deux fois : elle refuse la restauration côté serveur,
 * et elle dit au client s'il doit proposer le bouton — un bouton qui mènerait
 * à un refus certain n'a pas à s'afficher. Un seul endroit à lire pour savoir
 * ce qui est permis.
 */
@RequiredArgsConstructor
public class VerrouArreteService {

    private final CloturePeriodeRepository cloturePeriodeRepository;
    private final ClotureCaisseRepository clotureCaisseRepository;

    /**
     * Instantané des deux bornes, lu une seule fois.
     *
     * <p>Marquer toute une liste ne doit pas coûter deux requêtes par ligne :
     * on lit les bornes une fois, puis chaque date se juge en mémoire.
     */
    public record Verrous(LocalDate finDernierePeriode, LocalDate derniereClotureCaisse) {

        /** Vrai si un élément daté de ce jour peut encore être restauré. */
        public boolean autorise(LocalDate date) {
            if (date == null) return true;
            if (finDernierePeriode != null && !date.isAfter(finDernierePeriode)) return false;
            return derniereClotureCaisse == null || derniereClotureCaisse.isBefore(date);
        }
    }

    public Verrous verrous() {
        return new Verrous(
                cloturePeriodeRepository.findDerniere()
                        .map(derniere -> derniere.finPeriode()).orElse(null),
                clotureCaisseRepository.findDerniereDateClotureToutesCaisses().orElse(null));
    }

    /** Vrai si un élément daté de ce jour peut encore être restauré. */
    public boolean estRestaurable(LocalDate date) {
        return verrous().autorise(date);
    }

    /** Refuse la restauration si un arrêté couvre déjà cette date. */
    public void verifier(LocalDate date) {
        if (date == null) return;
        Verrous verrous = verrous();
        if (verrous.autorise(date)) return;

        LocalDate finPeriode = verrous.finDernierePeriode();
        if (finPeriode != null && !date.isAfter(finPeriode)) {
            throw new EcritureFigeeException("Le " + date + " appartient à une période comptable"
                    + " clôturée : les états du mois ont été arrêtés sans cet élément, il ne peut"
                    + " plus y être remis.");
        }
        throw new EcritureFigeeException("La caisse a été arrêtée le "
                + verrous.derniereClotureCaisse() + " : la journée du " + date + " est close, cet"
                + " élément ne peut plus y être remis.");
    }
}
