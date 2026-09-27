package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.CreanceVehicule;
import com.tmk.vtcmanager.application.domain.finance.FiltreCreances;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.spec.RechercheVehiculeChauffeur;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Component
@RequiredArgsConstructor
public class CreanceRepositoryAdapter implements CreanceRepository {

    private final JdbcTemplate jdbcTemplate;

    /** Mapper commun aux détails (par chauffeur et par véhicule). */
    private static final RowMapper<LigneCreance> LIGNE_MAPPER = (rs, i) -> LigneCreance.builder()
            .document(TypeDocumentCreance.valueOf(rs.getString("document")))
            .documentId(rs.getLong("document_id"))
            .vehiculeId(rs.getObject("vehicule_id", Long.class))
            .chauffeurId(rs.getObject("chauffeur_id", Long.class))
            .chauffeurNom(rs.getString("chauffeur_nom"))
            .dateReference(rs.getDate("date_reference").toLocalDate())
            .montantDu(rs.getBigDecimal("montant_du"))
            .montantRegle(rs.getBigDecimal("montant_regle"))
            .restant(rs.getBigDecimal("restant"))
            .build();

    /**
     * Restriction commune aux quatre lectures de la balance : le mois de
     * naissance du document et le mot-clé, confronté à l'immatriculation (avec
     * ou sans tirets ni espaces) comme au nom du chauffeur dans les deux ordres.
     * Suppose les alias {@code v} (vue), {@code ch} (chauffeur) et {@code veh}
     * (véhicule, joint en LEFT : une contravention peut ne pas en avoir).
     */
    private record Clause(String sql, List<Object> params) {

        static Clause de(FiltreCreances filtre) {
            StringBuilder sql = new StringBuilder();
            List<Object> params = new ArrayList<>();
            if (filtre.mois() != null) {
                sql.append(" AND v.date_reference >= ? AND v.date_reference < ?");
                params.add(filtre.mois().atDay(1));
                params.add(filtre.mois().plusMonths(1).atDay(1));
            }
            if (filtre.aUneRecherche()) {
                sql.append(" AND (LOWER(veh.immatriculation) LIKE ?")
                        .append(" OR REPLACE(REPLACE(LOWER(veh.immatriculation), '-', ''), ' ', '') LIKE ?")
                        .append(" OR LOWER(ch.nom) LIKE ?")
                        .append(" OR LOWER(ch.prenom) LIKE ?")
                        .append(" OR LOWER(CONCAT(ch.prenom, ' ', ch.nom)) LIKE ?")
                        .append(" OR LOWER(CONCAT(ch.nom, ' ', ch.prenom)) LIKE ?)");
                String motif = RechercheVehiculeChauffeur.motif(filtre.recherche());
                String motifCompact = motif.replace("-", "").replace(" ", "");
                params.addAll(List.of(motif, motifCompact, motif, motif, motif, motif));
            }
            return new Clause(sql.toString(), params);
        }

        Object[] avant(Object... premiers) {
            List<Object> tous = new ArrayList<>(List.of(premiers));
            tous.addAll(params);
            return tous.toArray();
        }
    }

    @Override
    public List<CreanceChauffeur> getBalanceAgee(FiltreCreances filtre) {
        Clause clause = Clause.de(filtre);
        return jdbcTemplate.query("""
                SELECT v.tiers_id AS chauffeur_id,
                       ch.nom, ch.prenom,
                       COUNT(*) AS nb_lignes,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference >  CURRENT_DATE - 8), 0)  AS du_0_7,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference <= CURRENT_DATE - 8
                                                         AND v.date_reference >  CURRENT_DATE - 31), 0) AS du_8_30,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference <= CURRENT_DATE - 31), 0) AS du_plus_30,
                       SUM(v.restant) AS total
                FROM v_creances_chauffeurs v
                JOIN chauffeurs ch ON ch.id = v.tiers_id
                LEFT JOIN vehicules veh ON veh.id = v.vehicule_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'%s
                GROUP BY v.tiers_id, ch.nom, ch.prenom
                ORDER BY total DESC
                """.formatted(clause.sql()),
                (rs, i) -> CreanceChauffeur.builder()
                        .chauffeurId(rs.getLong("chauffeur_id"))
                        .chauffeurNom(rs.getString("nom"))
                        .chauffeurPrenom(rs.getString("prenom"))
                        .nbLignes(rs.getInt("nb_lignes"))
                        .du0a7Jours(rs.getBigDecimal("du_0_7"))
                        .du8a30Jours(rs.getBigDecimal("du_8_30"))
                        .duPlus30Jours(rs.getBigDecimal("du_plus_30"))
                        .total(rs.getBigDecimal("total"))
                        .build(),
                clause.avant());
    }

    @Override
    public List<LigneCreance> getLignesCreance(Long chauffeurId, FiltreCreances filtre) {
        Clause clause = Clause.de(filtre);
        return jdbcTemplate.query("""
                SELECT v.document, v.document_id, v.vehicule_id,
                       v.tiers_id AS chauffeur_id,
                       TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS chauffeur_nom,
                       v.date_reference, v.montant_du, v.montant_regle, v.restant
                FROM v_creances_chauffeurs v
                JOIN chauffeurs ch ON ch.id = v.tiers_id
                LEFT JOIN vehicules veh ON veh.id = v.vehicule_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.tiers_id = ?%s
                ORDER BY v.date_reference
                """.formatted(clause.sql()), LIGNE_MAPPER, clause.avant(chauffeurId));
    }

    /**
     * Sur l'axe véhicule, les dettes du véhicule lui-même — contraventions que
     * personne ne porte — s'ajoutent à celles de ses chauffeurs : d'où le
     * {@code LEFT JOIN} sur le chauffeur, absent pour elles.
     */
    @Override
    public List<CreanceVehicule> getBalanceAgeeParVehicule(FiltreCreances filtre) {
        Clause clause = Clause.de(filtre);
        return jdbcTemplate.query("""
                SELECT v.vehicule_id,
                       veh.immatriculation, mar.nom AS marque, mod.nom AS modele,
                       COUNT(*) AS nb_lignes,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference >  CURRENT_DATE - 8), 0)  AS du_0_7,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference <= CURRENT_DATE - 8
                                                         AND v.date_reference >  CURRENT_DATE - 31), 0) AS du_8_30,
                       COALESCE(SUM(v.restant) FILTER (WHERE v.date_reference <= CURRENT_DATE - 31), 0) AS du_plus_30,
                       SUM(v.restant) AS total
                FROM v_creances_chauffeurs v
                JOIN vehicules veh ON veh.id = v.vehicule_id
                LEFT JOIN chauffeurs ch ON v.tiers_type = 'CHAUFFEUR' AND ch.id = v.tiers_id
                LEFT JOIN marques mar ON mar.id = veh.marque_id
                LEFT JOIN modeles mod ON mod.id = veh.modele_id
                WHERE v.tiers_type IN ('CHAUFFEUR', 'VEHICULE') AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.vehicule_id IS NOT NULL%s
                GROUP BY v.vehicule_id, veh.immatriculation, mar.nom, mod.nom
                ORDER BY total DESC
                """.formatted(clause.sql()),
                (rs, i) -> CreanceVehicule.builder()
                        .vehiculeId(rs.getLong("vehicule_id"))
                        .immatriculation(rs.getString("immatriculation"))
                        .marque(rs.getString("marque"))
                        .modele(rs.getString("modele"))
                        .nbLignes(rs.getInt("nb_lignes"))
                        .du0a7Jours(rs.getBigDecimal("du_0_7"))
                        .du8a30Jours(rs.getBigDecimal("du_8_30"))
                        .duPlus30Jours(rs.getBigDecimal("du_plus_30"))
                        .total(rs.getBigDecimal("total"))
                        .build(),
                clause.avant());
    }

    @Override
    public List<LigneCreance> getLignesCreanceParVehicule(Long vehiculeId, FiltreCreances filtre) {
        Clause clause = Clause.de(filtre);
        return jdbcTemplate.query("""
                SELECT v.document, v.document_id, v.vehicule_id,
                       ch.id AS chauffeur_id,
                       NULLIF(TRIM(CONCAT(ch.prenom, ' ', ch.nom)), '') AS chauffeur_nom,
                       v.date_reference, v.montant_du, v.montant_regle, v.restant
                FROM v_creances_chauffeurs v
                LEFT JOIN chauffeurs ch ON v.tiers_type = 'CHAUFFEUR' AND ch.id = v.tiers_id
                LEFT JOIN vehicules veh ON veh.id = v.vehicule_id
                WHERE v.tiers_type IN ('CHAUFFEUR', 'VEHICULE') AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.vehicule_id = ?%s
                ORDER BY v.date_reference
                """.formatted(clause.sql()), LIGNE_MAPPER, clause.avant(vehiculeId));
    }

    @Override
    public BigDecimal getMontantAReverserEtat() {
        BigDecimal montant = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(COALESCE(montant_paye, 0)), 0)
                FROM contraventions
                WHERE statut IN ('EN_ATTENTE', 'PARTIELLEMENT_PAYE', 'PAYE')
                """, BigDecimal.class);
        return montant == null ? BigDecimal.ZERO : montant;
    }

    @Override
    public BigDecimal getMontantAReverserEtatALaDate(LocalDate date) {
        // Encaissé du chauffeur au plus tard ce jour-là, et pas encore reversé
        // à cette date : une contravention reversée depuis était bien une dette
        // au soir de la période.
        BigDecimal montant = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(COALESCE(montant_paye, 0)), 0)
                FROM contraventions
                WHERE COALESCE(montant_paye, 0) > 0
                  AND date_paiement IS NOT NULL
                  AND date_paiement <= ?
                  AND (date_reversement IS NULL OR date_reversement > ?)
                """, BigDecimal.class, date, date);
        return montant == null ? BigDecimal.ZERO : montant;
    }

    @Override
    public List<CreanceChauffeur> getBalanceAgeeALaDate(LocalDate date) {
        // Un seul paramètre, repris partout via `bornes` : la date d'arrêté
        // pilote à la fois la sélection des documents, celle des règlements
        // retenus et le calcul des tranches d'ancienneté.
        //
        // Les annulations sont datées, documents comme règlements : une ligne
        // annulée en août reste due dans la photo de juillet, où elle figurait
        // bien à l'actif. Une contravention s'annule par sa seule date — son
        // statut ne bouge pas —, d'où le test sur annule_le plutôt que sur lui.
        // La cotisation n'y figure pas : c'est l'épargne du chauffeur, pas une
        // dette (même périmètre que v_creances_chauffeurs).
        return jdbcTemplate.query("""
                WITH bornes AS (SELECT CAST(? AS date) AS d),
                docs AS (
                    SELECT lr.chauffeur_id AS tiers_id,
                           lr.date_recette AS date_reference,
                           lr.montant_attendu - COALESCE((
                               SELECT SUM(e.montant) FROM encaissements e
                                WHERE e.ligne_recette_id = lr.id
                                  AND e.date_encaissement <= (SELECT d FROM bornes)
                                  AND (e.annule_le IS NULL
                                       OR e.annule_le::date > (SELECT d FROM bornes))), 0) AS restant
                      FROM lignes_recette lr
                     WHERE (lr.annule_le IS NULL
                            OR lr.annule_le::date > (SELECT d FROM bornes))
                       AND lr.montant_attendu IS NOT NULL
                       AND lr.chauffeur_id IS NOT NULL
                       AND lr.date_recette <= (SELECT d FROM bornes)
                    UNION ALL
                    SELECT lp.chauffeur_id,
                           COALESCE(lp.date_faute, lp.date_generation),
                           lp.montant - COALESCE((
                               SELECT SUM(e.montant) FROM encaissements_penalite e
                                WHERE e.ligne_penalite_id = lp.id
                                  AND e.date_encaissement <= (SELECT d FROM bornes)
                                  AND (e.annule_le IS NULL
                                       OR e.annule_le::date > (SELECT d FROM bornes))), 0)
                      FROM lignes_penalite lp
                     WHERE lp.type_sanction = 'AMENDE'
                       AND (lp.annule_le IS NULL
                            OR lp.annule_le::date > (SELECT d FROM bornes))
                       AND lp.montant IS NOT NULL
                       AND lp.chauffeur_id IS NOT NULL
                       AND COALESCE(lp.date_faute, lp.date_generation) <= (SELECT d FROM bornes)
                    UNION ALL
                    SELECT ct.chauffeur_id,
                           ct.date_infraction,
                           ct.montant - CASE
                               WHEN ct.date_paiement IS NOT NULL
                                    AND ct.date_paiement <= (SELECT d FROM bornes)
                               THEN COALESCE(ct.montant_paye, 0) ELSE 0 END
                      FROM contraventions ct
                     WHERE (ct.annule_le IS NULL
                            OR ct.annule_le::date > (SELECT d FROM bornes))
                       AND (ct.statut IS NULL OR ct.statut <> 'ANNULE')
                       AND ct.chauffeur_id IS NOT NULL
                       AND ct.montant IS NOT NULL
                       AND ct.date_infraction <= (SELECT d FROM bornes)
                )
                SELECT docs.tiers_id AS chauffeur_id,
                       ch.nom, ch.prenom,
                       COUNT(*) AS nb_lignes,
                       COALESCE(SUM(docs.restant) FILTER (
                           WHERE docs.date_reference > (SELECT d FROM bornes) - 8), 0) AS du_0_7,
                       COALESCE(SUM(docs.restant) FILTER (
                           WHERE docs.date_reference <= (SELECT d FROM bornes) - 8
                             AND docs.date_reference > (SELECT d FROM bornes) - 31), 0) AS du_8_30,
                       COALESCE(SUM(docs.restant) FILTER (
                           WHERE docs.date_reference <= (SELECT d FROM bornes) - 31), 0) AS du_plus_30,
                       SUM(docs.restant) AS total
                  FROM docs
                  JOIN chauffeurs ch ON ch.id = docs.tiers_id
                 WHERE docs.restant > 0
                 GROUP BY docs.tiers_id, ch.nom, ch.prenom
                 ORDER BY total DESC
                """,
                (rs, i) -> CreanceChauffeur.builder()
                        .chauffeurId(rs.getLong("chauffeur_id"))
                        .chauffeurNom(rs.getString("nom"))
                        .chauffeurPrenom(rs.getString("prenom"))
                        .nbLignes(rs.getInt("nb_lignes"))
                        .du0a7Jours(rs.getBigDecimal("du_0_7"))
                        .du8a30Jours(rs.getBigDecimal("du_8_30"))
                        .duPlus30Jours(rs.getBigDecimal("du_plus_30"))
                        .total(rs.getBigDecimal("total"))
                        .build(),
                date);
    }
}
