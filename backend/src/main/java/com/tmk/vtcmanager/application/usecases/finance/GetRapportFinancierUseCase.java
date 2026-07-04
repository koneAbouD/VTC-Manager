package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.GroupByRapport;
import com.tmk.vtcmanager.application.domain.finance.RapportFinancier;
import com.tmk.vtcmanager.application.domain.finance.RapportFinancier.LigneOperation;
import com.tmk.vtcmanager.application.domain.finance.RapportFinancier.LigneRepartition;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.NatureResultat;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Construit le rapport financier d'un mois : totaux revenus/dépenses (avec
 * variation sur le mois précédent), répartitions et liste des opérations.
 *
 * <p>Le périmètre reprend celui du compte de résultat en base caisse : seules
 * les opérations terminées (encaissées/payées) sont prises en compte et les
 * catégories HORS_RESULTAT (comptes de tiers) sont exclues. Les montants sont
 * stockés en valeur positive quel que soit le type ; le signe est porté par
 * {@link TypeOperation}.</p>
 */
@RequiredArgsConstructor
public class GetRapportFinancierUseCase {

    private final OperationFinanciereRepository operationRepository;

    @Transactional(readOnly = true)
    public RapportFinancier executer(int annee, int mois, GroupByRapport groupBy) {
        YearMonth periode = YearMonth.of(annee, mois);
        List<OperationFinanciere> operations = operationsTerminees(periode);
        List<OperationFinanciere> operationsPrecedentes = operationsTerminees(periode.minusMonths(1));

        BigDecimal totalRevenus = total(operations, TypeOperation.REVENU);
        BigDecimal totalDepenses = total(operations, TypeOperation.DEPENSE);

        return RapportFinancier.builder()
                .totalRevenus(totalRevenus)
                .totalDepenses(totalDepenses)
                .variationRevenusPct(variation(totalRevenus, total(operationsPrecedentes, TypeOperation.REVENU)))
                .variationDepensesPct(variation(totalDepenses, total(operationsPrecedentes, TypeOperation.DEPENSE)))
                .groupBy(groupBy.name())
                .breakdownRevenus(repartition(operations, TypeOperation.REVENU, totalRevenus,
                        op -> labelRevenu(op, groupBy)))
                .breakdownDepenses(repartition(operations, TypeOperation.DEPENSE, totalDepenses,
                        this::labelDepense))
                .listeOperations(lignes(operations))
                .build();
    }

    /** Opérations terminées de la période, catégories HORS_RESULTAT exclues. */
    private List<OperationFinanciere> operationsTerminees(YearMonth periode) {
        var filtres = new OperationFinanciereFiltres(
                null, periode.atDay(1), periode.atEndOfMonth(),
                null, null, null, null, null, null);
        return operationRepository.findByCriteres(filtres).stream()
                .filter(op -> op.getStatut() != null && op.getStatut().estTerminee())
                .filter(op -> nature(op) != NatureResultat.HORS_RESULTAT)
                .toList();
    }

    private BigDecimal total(List<OperationFinanciere> operations, TypeOperation type) {
        return operations.stream()
                .filter(op -> op.getTypeOperation() == type)
                .map(this::montant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private List<LigneRepartition> repartition(List<OperationFinanciere> operations, TypeOperation type,
                                               BigDecimal total,
                                               java.util.function.Function<OperationFinanciere, String> label) {
        Map<String, BigDecimal> parGroupe = new LinkedHashMap<>();
        operations.stream()
                .filter(op -> op.getTypeOperation() == type)
                .forEach(op -> parGroupe.merge(label.apply(op), montant(op), BigDecimal::add));

        return parGroupe.entrySet().stream()
                .sorted(Map.Entry.<String, BigDecimal>comparingByValue().reversed())
                .map(e -> LigneRepartition.builder()
                        .label(e.getKey())
                        .montant(e.getValue())
                        .pourcentage(pourcentage(e.getValue(), total))
                        .build())
                .toList();
    }

    private List<LigneOperation> lignes(List<OperationFinanciere> operations) {
        List<LigneOperation> lignes = new ArrayList<>();
        for (OperationFinanciere op : operations) {
            lignes.add(LigneOperation.builder()
                    .id(op.getId())
                    .type(op.getTypeOperation() == null ? null : op.getTypeOperation().name())
                    .description(description(op))
                    .chauffeurNom(nomChauffeur(op))
                    .vehiculeLabel(labelVehicule(op))
                    .montant(montant(op))
                    .date(op.getDateReference() != null ? op.getDateReference() : op.getDateOperation())
                    .build());
        }
        return lignes;
    }

    // ── Libellés ──────────────────────────────────────────────────────────

    private String labelRevenu(OperationFinanciere op, GroupByRapport groupBy) {
        return groupBy == GroupByRapport.VEHICULE
                ? labelVehiculeOuDefaut(op, "Sans véhicule")
                : nomChauffeurOuDefaut(op, "Sans chauffeur");
    }

    private String labelDepense(OperationFinanciere op) {
        CategorieOperation categorie = op.getCategorie();
        if (categorie != null && categorie.getLibelle() != null && !categorie.getLibelle().isBlank()) {
            return categorie.getLibelle();
        }
        return "Autres";
    }

    private String description(OperationFinanciere op) {
        if (op.getCommentaire() != null && !op.getCommentaire().isBlank()) {
            return op.getCommentaire();
        }
        if (op.getSousCategorie() != null && op.getSousCategorie().getLibelle() != null
                && !op.getSousCategorie().getLibelle().isBlank()) {
            return op.getSousCategorie().getLibelle();
        }
        if (op.getCategorie() != null && op.getCategorie().getLibelle() != null) {
            return op.getCategorie().getLibelle();
        }
        return op.getReference();
    }

    private String nomChauffeur(OperationFinanciere op) {
        if (op.getChauffeur() == null) return null;
        String nom = String.format("%s %s",
                op.getChauffeur().getPrenom() == null ? "" : op.getChauffeur().getPrenom(),
                op.getChauffeur().getNom() == null ? "" : op.getChauffeur().getNom()).trim();
        return nom.isEmpty() ? null : nom;
    }

    private String nomChauffeurOuDefaut(OperationFinanciere op, String defaut) {
        String nom = nomChauffeur(op);
        return nom == null ? defaut : nom;
    }

    private String labelVehicule(OperationFinanciere op) {
        if (op.getVehicule() == null || op.getVehicule().getImmatriculation() == null
                || op.getVehicule().getImmatriculation().isBlank()) {
            return null;
        }
        return op.getVehicule().getImmatriculation();
    }

    private String labelVehiculeOuDefaut(OperationFinanciere op, String defaut) {
        String label = labelVehicule(op);
        return label == null ? defaut : label;
    }

    // ── Calculs ───────────────────────────────────────────────────────────

    private NatureResultat nature(OperationFinanciere op) {
        return op.getCategorie() == null ? null : op.getCategorie().getNatureResultat();
    }

    /** Montant en valeur absolue (les montants sont stockés positifs, garde défensive). */
    private BigDecimal montant(OperationFinanciere op) {
        return op.getMontant() == null ? BigDecimal.ZERO : op.getMontant().abs();
    }

    private BigDecimal pourcentage(BigDecimal montant, BigDecimal total) {
        if (total == null || total.signum() == 0) return BigDecimal.ZERO;
        return montant.multiply(BigDecimal.valueOf(100))
                .divide(total, 1, RoundingMode.HALF_UP);
    }

    private BigDecimal variation(BigDecimal courant, BigDecimal precedent) {
        if (precedent == null || precedent.signum() == 0) return BigDecimal.ZERO;
        return courant.subtract(precedent)
                .multiply(BigDecimal.valueOf(100))
                .divide(precedent, 1, RoundingMode.HALF_UP);
    }
}
