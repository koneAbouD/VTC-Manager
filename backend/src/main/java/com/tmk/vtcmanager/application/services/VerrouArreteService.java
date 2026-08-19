package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.Map;

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
    public record Verrous(LocalDate finDernierePeriode,
                          LocalDate derniereClotureCaisse,
                          Map<Long, LocalDate> derniereClotureParCompte) {

        /**
         * Vrai si un élément daté de ce jour peut encore être restauré.
         *
         * <p>Pour une créance ou une intervention, qui ne mouvemente aucune
         * caisse en propre, c'est le dernier comptage toutes caisses confondues
         * qui fait foi.
         */
        public boolean autorise(LocalDate date) {
            if (date == null) return true;
            if (periodeClose(date)) return false;
            return derniereClotureCaisse == null || derniereClotureCaisse.isBefore(date);
        }

        /**
         * Vrai si une écriture datée de ce jour, passée par ce compte, peut
         * encore être contre-passée.
         *
         * <p>Ici la caisse est connue : seul son propre comptage la fige. Un
         * comptage de la caisse secondaire ne doit pas geler ce qui est passé
         * par la principale — c'est la caisse mouvementée qu'un procès-verbal
         * engage, pas les autres.
         */
        public boolean autoriseEcriture(LocalDate date, Long compteId) {
            if (date == null) return true;
            if (periodeClose(date)) return false;
            if (compteId == null) return true;
            LocalDate dernierComptage = derniereClotureParCompte.get(compteId);
            return dernierComptage == null || dernierComptage.isBefore(date);
        }

        private boolean periodeClose(LocalDate date) {
            return finDernierePeriode != null && !date.isAfter(finDernierePeriode);
        }
    }

    public Verrous verrous() {
        return new Verrous(
                cloturePeriodeRepository.findDerniere()
                        .map(derniere -> derniere.finPeriode()).orElse(null),
                clotureCaisseRepository.findDerniereDateClotureToutesCaisses().orElse(null),
                clotureCaisseRepository.findDernieresClotureParCompte());
    }

    /** Vrai si l'écriture de ce compte, datée de ce jour, reste contre-passable. */
    public boolean estAnnulable(LocalDate date, Long compteId) {
        return verrous().autoriseEcriture(date, compteId);
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
