package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.CreanceVehicule;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
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

    @Override
    public List<CreanceChauffeur> getBalanceAgee() {
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
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                GROUP BY v.tiers_id, ch.nom, ch.prenom
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
                        .build());
    }

    @Override
    public List<LigneCreance> getLignesCreance(Long chauffeurId) {
        return jdbcTemplate.query("""
                SELECT v.document, v.document_id, v.vehicule_id,
                       v.tiers_id AS chauffeur_id,
                       TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS chauffeur_nom,
                       v.date_reference, v.montant_du, v.montant_regle, v.restant
                FROM v_creances_chauffeurs v
                JOIN chauffeurs ch ON ch.id = v.tiers_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.tiers_id = ?
                ORDER BY v.date_reference
                """, LIGNE_MAPPER, chauffeurId);
    }

    @Override
    public List<CreanceVehicule> getBalanceAgeeParVehicule() {
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
                LEFT JOIN marques mar ON mar.id = veh.marque_id
                LEFT JOIN modeles mod ON mod.id = veh.modele_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.vehicule_id IS NOT NULL
                GROUP BY v.vehicule_id, veh.immatriculation, mar.nom, mod.nom
                ORDER BY total DESC
                """,
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
                        .build());
    }

    @Override
    public List<LigneCreance> getLignesCreanceParVehicule(Long vehiculeId) {
        return jdbcTemplate.query("""
                SELECT v.document, v.document_id, v.vehicule_id,
                       v.tiers_id AS chauffeur_id,
                       TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS chauffeur_nom,
                       v.date_reference, v.montant_du, v.montant_regle, v.restant
                FROM v_creances_chauffeurs v
                JOIN chauffeurs ch ON ch.id = v.tiers_id
                WHERE v.tiers_type = 'CHAUFFEUR' AND v.sens = 'ILS_ME_DOIVENT'
                  AND v.vehicule_id = ?
                ORDER BY v.date_reference
                """, LIGNE_MAPPER, vehiculeId);
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
        // bien à l'actif. Le statut courant ne sert plus que pour les
        // contraventions, dont l'annulation n'est pas implémentée.
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
                    SELECT lc.chauffeur_id,
                           lc.date_cotisation,
                           lc.montant_du - COALESCE((
                               SELECT SUM(e.montant) FROM encaissements_cotisation e
                                WHERE e.ligne_cotisation_id = lc.id
                                  AND e.date_encaissement <= (SELECT d FROM bornes)
                                  AND (e.annule_le IS NULL
                                       OR e.annule_le::date > (SELECT d FROM bornes))), 0)
                      FROM lignes_cotisation lc
                     WHERE (lc.annule_le IS NULL
                            OR lc.annule_le::date > (SELECT d FROM bornes))
                       AND lc.montant_du IS NOT NULL
                       AND lc.chauffeur_id IS NOT NULL
                       AND lc.date_cotisation <= (SELECT d FROM bornes)
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
