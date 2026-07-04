package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.YearMonth;
import java.util.List;

@RequiredArgsConstructor
public class ExportComptableUseCase {

    private final OperationFinanciereRepository operationRepository;

    /**
     * Journal CSV de la période pour le cabinet comptable : une ligne par
     * opération terminée, avec le compte du plan comptable si la catégorie
     * est mappée (colonne vide sinon — le cabinet complète). Séparateur « ; »
     * (convention des exports existants de l'app).
     */
    @Transactional(readOnly = true)
    public String executer(int annee, int mois) {
        YearMonth periode = YearMonth.of(annee, mois);
        List<OperationFinanciere> operations = operationRepository.findByCriteres(
                new OperationFinanciereFiltres(null, periode.atDay(1), periode.atEndOfMonth(),
                        null, null, null, null, null, null));

        StringBuilder csv = new StringBuilder(
                "Date;Référence;Catégorie;Compte;Nature;Débit;Crédit;Chauffeur;Véhicule;Mode;Commentaire\n");
        operations.stream()
                .filter(o -> o.getStatut() != null && o.getStatut().estTerminee())
                .sorted((a, b) -> a.getDateOperation().compareTo(b.getDateOperation()))
                .forEach(o -> csv.append(ligneCsv(o)));
        return csv.toString();
    }

    private String ligneCsv(OperationFinanciere o) {
        boolean revenu = o.getTypeOperation() == TypeOperation.REVENU;
        String categorie = o.getCategorie() != null ? o.getCategorie().getLibelle() : "";
        String compte = o.getCategorie() != null && o.getCategorie().getCompteComptable() != null
                ? o.getCategorie().getCompteComptable() : "";
        String nature = o.getCategorie() != null && o.getCategorie().getNatureResultat() != null
                ? o.getCategorie().getNatureResultat().name() : "";
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
                revenu ? "" : o.getMontant().toPlainString(),
                revenu ? o.getMontant().toPlainString() : "",
                echapper(chauffeur),
                echapper(vehicule),
                o.getModePaiement() != null ? o.getModePaiement().name() : "",
                echapper(o.getCommentaire() != null ? o.getCommentaire() : "")) + "\n";
    }

    private String echapper(String valeur) {
        if (valeur == null) return "";
        if (valeur.contains(";") || valeur.contains("\"") || valeur.contains("\n")) {
            return "\"" + valeur.replace("\"", "\"\"") + "\"";
        }
        return valeur;
    }
}
