package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.NatureResultat;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.YearMonth;
import java.util.Comparator;
import java.util.List;

@RequiredArgsConstructor
public class ExportComptableUseCase {

    /** Catégorie du dépôt de cotisations : son compte porte la dette envers les chauffeurs. */
    static final String CAT_DEPOT_COTISATIONS = "ENCAISSEMENT_COTISATIONS";
    static final String LIBELLE_DEPOT = "Dépôts cotisations chauffeurs";
    static final String MODE_COMPENSATION = "COMPENSATION";

    private final OperationFinanciereRepository operationRepository;
    private final CategorieOperationRepository categorieOperationRepository;

    /**
     * Journal CSV de la période pour le cabinet comptable : une ligne par
     * opération terminée, avec le compte du plan comptable si la catégorie
     * est mappée (colonne vide sinon — le cabinet complète). Séparateur « ; »
     * (convention des exports existants de l'app).
     *
     * <p><b>Compensations d'arrêté</b> : elles ne sont pas des encaissements.
     * Le cash est entré avec la cotisation (compte de dépôt) ; l'arrêté en
     * reclasse une part en produit pour éteindre la créance. Exportée comme une
     * ligne d'encaissement ordinaire, elle faisait compter la caisse deux fois
     * et laissait le dépôt au passif. Elle sort donc en opération diverse
     * équilibrée : débit du dépôt, crédit du produit, mode COMPENSATION.
     */
    @Transactional(readOnly = true)
    public String executer(int annee, int mois) {
        YearMonth periode = YearMonth.of(annee, mois);
        List<OperationFinanciere> operations = operationRepository.findByCriteres(
                new OperationFinanciereFiltres(null, periode.atDay(1), periode.atEndOfMonth(),
                        null, null, null, null, null, null, null));
        CategorieOperation depot = categorieOperationRepository
                .findByCode(CAT_DEPOT_COTISATIONS).orElse(null);

        StringBuilder csv = new StringBuilder(
                "Date;Référence;Catégorie;Compte;Nature;Débit;Crédit;Chauffeur;Véhicule;Mode;Commentaire\n");
        operations.stream()
                .filter(o -> o.getStatut() != null && o.getStatut().estTerminee())
                .sorted(Comparator.comparing(OperationFinanciere::getDateOperation))
                .forEach(o -> {
                    if (o.estUneCompensation()) {
                        csv.append(lignesCompensation(o, depot));
                    } else {
                        csv.append(ligneCsv(o));
                    }
                });
        return csv.toString();
    }

    private String ligneCsv(OperationFinanciere o) {
        boolean revenu = o.getTypeOperation() == TypeOperation.REVENU;
        return ligne(o, libelle(o.getCategorie()), compte(o.getCategorie()), nature(o.getCategorie()),
                !revenu, o.getModePaiement() != null ? o.getModePaiement().name() : "");
    }

    /**
     * Les deux jambes du reclassement, sous la même référence : le dépôt du
     * chauffeur diminue (débit), le produit de la créance éteinte est constaté
     * (crédit). Aucune ligne de trésorerie.
     */
    private String lignesCompensation(OperationFinanciere o, CategorieOperation depot) {
        String natureDepot = depot != null && depot.getNatureResultat() != null
                ? depot.getNatureResultat().name() : NatureResultat.HORS_RESULTAT.name();
        return ligne(o, LIBELLE_DEPOT, compte(depot), natureDepot, true, MODE_COMPENSATION)
                + ligne(o, libelle(o.getCategorie()), compte(o.getCategorie()), nature(o.getCategorie()),
                        false, MODE_COMPENSATION);
    }

    private String ligne(OperationFinanciere o, String categorie, String compte, String nature,
                         boolean debit, String mode) {
        String montant = o.getMontant().toPlainString();
        String chauffeur = o.getChauffeur() != null && o.getChauffeur().getNom() != null
                ? (o.getChauffeur().getPrenom() != null ? o.getChauffeur().getPrenom() + " " : "")
                        + o.getChauffeur().getNom()
                : "";
        String vehicule = o.getVehicule() != null && o.getVehicule().getImmatriculation() != null
                ? o.getVehicule().getImmatriculation() : "";

        return String.join(";",
                o.getDateOperation().toString(),
                echapper(o.getReference()),
                echapper(categorie),
                compte,
                nature,
                debit ? montant : "",
                debit ? "" : montant,
                echapper(chauffeur),
                echapper(vehicule),
                mode,
                echapper(o.getCommentaire() != null ? o.getCommentaire() : "")) + "\n";
    }

    private static String libelle(CategorieOperation c) {
        return c != null && c.getLibelle() != null ? c.getLibelle() : "";
    }

    private static String compte(CategorieOperation c) {
        return c != null && c.getCompteComptable() != null ? c.getCompteComptable() : "";
    }

    private static String nature(CategorieOperation c) {
        return c != null && c.getNatureResultat() != null ? c.getNatureResultat().name() : "";
    }

    private String echapper(String valeur) {
        if (valeur == null) return "";
        if (valeur.contains(";") || valeur.contains("\"") || valeur.contains("\n")) {
            return "\"" + valeur.replace("\"", "\"\"") + "\"";
        }
        return valeur;
    }
}
