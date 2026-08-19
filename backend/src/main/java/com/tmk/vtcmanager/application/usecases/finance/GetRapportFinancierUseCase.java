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
 * catégories HORS_RESULTAT (comptes de tiers) sont exclues. Le sens revenu /
 * dépense est porté par {@link TypeOperation}, et le montant reste sommé
 * <em>signé</em> : une écriture annulée demeure au journal avec son statut
 * terminal, et c'est la contre-passation de montant opposé qui l'efface des
 * totaux — exactement comme dans les agrégats SQL du compte de résultat.</p>
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
                null, null, null, null, null, null, null);
        return operationRepository.findByCriteres(filtres).stream()
                .filter(op -> op.getStatut() != null && op.getStatut().estTerminee())
                .filter(op -> nature(op) != NatureResultat.HORS_RESULTAT)
                .toList();
    }

    /** Somme signée du type : le couple origine + extourne s'y annule. */
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
                // Un groupe dont tout a été extourné retombe à zéro : la part
                // n'existe plus, et une ligne « 0 F — 0 % » n'aurait rien à
                // montrer. Les groupes devenus négatifs, eux, sont conservés :
                // ils signalent une extourne du mois qui dépasse les écritures
                // qu'il porte, et c'est une information, pas un artefact.
                .filter(e -> e.getValue().signum() != 0)
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
                    .categorieCode(op.getCategorie() == null ? null : op.getCategorie().getCode())
                    .categorieLibelle(op.getCategorie() == null ? null : op.getCategorie().getLibelle())
                    .chauffeurNom(nomChauffeur(op))
                    .vehiculeLabel(labelVehicule(op))
                    // Même montant signé que les agrégats : le client lit le
                    // sens réel sur la caisse, une extourne de dépense faisant
                    // rentrer l'argent.
                    .montant(montant(op))
                    .date(op.getDateReference() != null ? op.getDateReference() : op.getDateOperation())
                    .estUneExtourne(op.estUneExtourne())
                    .estExtournee(op.estExtournee())
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

    /**
     * Codes des catégories de dépense « documents » (famille comptable
     * Documents), regroupées sous une seule entrée « Document » dans la
     * répartition. Miroir des sous-catégories seedées (groupe « Documents »).
     */
    private static final java.util.Set<String> CODES_DOCUMENT = java.util.Set.of(
            "ASSURANCE", "VISITE_TECHNIQUE", "PATENTE", "CARTE_STATIONNEMENT",
            "VIGNETTE", "TAXE");

    private String labelDepense(OperationFinanciere op) {
        CategorieOperation categorie = op.getCategorie();
        if (categorie == null) {
            return "Autres";
        }
        if (categorie.getCode() != null && CODES_DOCUMENT.contains(categorie.getCode())) {
            return "Document";
        }
        if (categorie.getLibelle() != null && !categorie.getLibelle().isBlank()) {
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

    /**
     * Montant <b>signé</b> de l'écriture.
     *
     * <p>C'est le signe qui porte l'annulation : une contre-passation reprend le
     * type, la catégorie et le statut de son origine — les deux écritures
     * franchissent donc le filtre {@code estTerminee()} — et seul son montant
     * opposé les neutralise dans les agrégats. Les sommer en valeur absolue
     * comptait la dépense annulée deux fois au lieu de zéro.
     */
    private BigDecimal montant(OperationFinanciere op) {
        return op.getMontant() == null ? BigDecimal.ZERO : op.getMontant();
    }

    /**
     * Part d'un groupe dans le total. Le dénominateur est pris en valeur absolue :
     * un mois où les extournes l'emportent donne un total négatif, et diviser par
     * lui retournerait le signe de chaque part — un groupe négatif s'afficherait
     * positif. Un total nul (tout extourné) ne se répartit pas : 0 %.
     */
    private BigDecimal pourcentage(BigDecimal montant, BigDecimal total) {
        if (total == null || total.signum() == 0) return BigDecimal.ZERO;
        return montant.multiply(BigDecimal.valueOf(100))
                .divide(total.abs(), 1, RoundingMode.HALF_UP);
    }

    /**
     * Évolution sur le mois précédent, en pourcentage. Base en valeur absolue,
     * comme le tableau de bord : un mois précédent négatif — davantage extourné
     * qu'écrit — inverserait sinon le sens de la flèche servie au client.
     */
    private BigDecimal variation(BigDecimal courant, BigDecimal precedent) {
        if (precedent == null || precedent.signum() == 0) return BigDecimal.ZERO;
        return courant.subtract(precedent)
                .multiply(BigDecimal.valueOf(100))
                .divide(precedent.abs(), 1, RoundingMode.HALF_UP);
    }
}
