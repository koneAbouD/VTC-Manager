package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.arrete.StatutArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ArreteCompteRepositoryAdapter implements ArreteCompteRepository {

    private final JdbcTemplate jdbcTemplate;

    private static final RowMapper<ArreteCompte> ARRETE_MAPPER = (rs, i) -> ArreteCompte.builder()
            .id(rs.getLong("id"))
            .perimetre(PerimetreArrete.valueOf(rs.getString("perimetre")))
            .perimetreId(rs.getLong("perimetre_id"))
            .periodeDebut(rs.getDate("periode_debut").toLocalDate())
            .periodeFin(rs.getDate("periode_fin").toLocalDate())
            .dateArrete(rs.getDate("date_arrete").toLocalDate())
            .reference(rs.getString("reference"))
            .statut(StatutArrete.valueOf(rs.getString("statut")))
            .motifAnnulation(rs.getString("motif_annulation"))
            .build();

    private static final RowMapper<LigneArrete> LIGNE_MAPPER = (rs, i) -> LigneArrete.builder()
            .id(rs.getLong("id"))
            .arreteId(rs.getLong("arrete_id"))
            .document(TypeDocumentCreance.valueOf(rs.getString("document_type")))
            .documentId(rs.getLong("document_id"))
            .chauffeurId(rs.getObject("chauffeur_id", Long.class))
            .vehiculeId(rs.getObject("vehicule_id", Long.class))
            .montant(rs.getBigDecimal("montant"))
            .sens(SensArrete.valueOf(rs.getString("sens")))
            .operationId(rs.getObject("operation_id", Long.class))
            .immatriculation(rs.getString("immatriculation"))
            .build();

    private static final RowMapper<ReglementArrete> REGLEMENT_MAPPER = (rs, i) -> ReglementArrete.builder()
            .id(rs.getLong("id"))
            .arreteId(rs.getLong("arrete_id"))
            .chauffeurId(rs.getLong("chauffeur_id"))
            .chauffeurNom(rs.getString("chauffeur_nom"))
            .totalCotisations(rs.getBigDecimal("total_cotisations"))
            .totalCreancesCompensees(rs.getBigDecimal("total_creances_compensees"))
            .montantNet(rs.getBigDecimal("montant_net"))
            .reliquatReporte(rs.getBigDecimal("reliquat_reporte"))
            .modePaiement(rs.getString("mode_paiement") != null
                    ? ModePaiement.valueOf(rs.getString("mode_paiement")) : null)
            .compteTresorerieId(rs.getObject("compte_tresorerie_id", Long.class))
            .operationDecaissementId(rs.getObject("operation_decaissement_id", Long.class))
            .build();

    @Override
    public ArreteCompte enregistrerEntete(ArreteCompte a) {
        Long id = jdbcTemplate.queryForObject("""
                INSERT INTO arretes_compte
                    (perimetre, perimetre_id, periode_debut, periode_fin, date_arrete,
                     reference, statut, motif_annulation, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
                RETURNING id
                """, Long.class,
                a.getPerimetre().name(), a.getPerimetreId(), a.getPeriodeDebut(), a.getPeriodeFin(),
                a.getDateArrete(), a.getReference(), a.getStatut().name(), a.getMotifAnnulation());
        a.setId(id);
        return a;
    }

    @Override
    public void enregistrerLignes(List<LigneArrete> lignes) {
        jdbcTemplate.batchUpdate("""
                INSERT INTO lignes_arrete
                    (arrete_id, document_type, document_id, chauffeur_id, vehicule_id, montant, sens, operation_id, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
                """,
                lignes, lignes.size(),
                (ps, l) -> {
                    ps.setLong(1, l.getArreteId());
                    ps.setString(2, l.getDocument().name());
                    ps.setLong(3, l.getDocumentId());
                    ps.setObject(4, l.getChauffeurId());
                    ps.setObject(5, l.getVehiculeId());
                    ps.setBigDecimal(6, l.getMontant());
                    ps.setString(7, l.getSens().name());
                    ps.setObject(8, l.getOperationId());
                });
    }

    @Override
    public void enregistrerReglements(List<ReglementArrete> reglements) {
        jdbcTemplate.batchUpdate("""
                INSERT INTO reglements_arrete
                    (arrete_id, chauffeur_id, total_cotisations, total_creances_compensees,
                     montant_net, reliquat_reporte, mode_paiement, compte_tresorerie_id,
                     operation_decaissement_id, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
                """,
                reglements, reglements.size(),
                (ps, r) -> {
                    ps.setLong(1, r.getArreteId());
                    ps.setLong(2, r.getChauffeurId());
                    ps.setBigDecimal(3, r.getTotalCotisations());
                    ps.setBigDecimal(4, r.getTotalCreancesCompensees());
                    ps.setBigDecimal(5, r.getMontantNet());
                    ps.setBigDecimal(6, r.getReliquatReporte());
                    ps.setString(7, r.getModePaiement() != null ? r.getModePaiement().name() : null);
                    ps.setObject(8, r.getCompteTresorerieId());
                    ps.setObject(9, r.getOperationDecaissementId());
                });
    }

    @Override
    public Optional<ArreteCompte> findById(Long id) {
        List<ArreteCompte> entetes = jdbcTemplate.query(
                "SELECT * FROM arretes_compte WHERE id = ?", ARRETE_MAPPER, id);
        if (entetes.isEmpty()) return Optional.empty();

        ArreteCompte arrete = entetes.get(0);
        if (arrete.getPerimetre() == PerimetreArrete.VEHICULE) {
            jdbcTemplate.query("SELECT immatriculation FROM vehicules WHERE id = ?",
                            (rs, i) -> rs.getString(1), arrete.getPerimetreId())
                    .stream().findFirst().ifPresent(arrete::setPerimetreLibelle);
        }
        arrete.setLignes(jdbcTemplate.query("""
                SELECT la.*, v.immatriculation
                FROM lignes_arrete la
                LEFT JOIN vehicules v ON v.id = la.vehicule_id
                WHERE la.arrete_id = ?
                ORDER BY la.sens DESC, la.id
                """, LIGNE_MAPPER, id));
        arrete.setReglements(jdbcTemplate.query("""
                SELECT r.*, TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS chauffeur_nom
                FROM reglements_arrete r
                JOIN chauffeurs ch ON ch.id = r.chauffeur_id
                WHERE r.arrete_id = ?
                ORDER BY r.id
                """, REGLEMENT_MAPPER, id));
        return Optional.of(arrete);
    }

    @Override
    public List<ArreteCompte> findAll() {
        List<ArreteCompte> entetes = jdbcTemplate.query(
                "SELECT * FROM arretes_compte ORDER BY date_arrete DESC, id DESC", ARRETE_MAPPER);
        for (ArreteCompte a : entetes) {
            a.setReglements(jdbcTemplate.query("""
                    SELECT r.*, TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS chauffeur_nom
                    FROM reglements_arrete r
                    JOIN chauffeurs ch ON ch.id = r.chauffeur_id
                    WHERE r.arrete_id = ?
                    ORDER BY r.id
                    """, REGLEMENT_MAPPER, a.getId()));
        }
        return entetes;
    }

    @Override
    public List<ArreteCompte> findByBeneficiaire(Long chauffeurId) {
        List<ArreteCompte> entetes = jdbcTemplate.query("""
                SELECT a.* FROM arretes_compte a
                WHERE EXISTS (SELECT 1 FROM reglements_arrete r
                              WHERE r.arrete_id = a.id AND r.chauffeur_id = ?)
                ORDER BY a.date_arrete DESC, a.id DESC
                """, ARRETE_MAPPER, chauffeurId);
        for (ArreteCompte a : entetes) {
            a.setReglements(jdbcTemplate.query("""
                    SELECT r.*, TRIM(CONCAT(ch.prenom, ' ', ch.nom)) AS chauffeur_nom
                    FROM reglements_arrete r
                    JOIN chauffeurs ch ON ch.id = r.chauffeur_id
                    WHERE r.arrete_id = ?
                    ORDER BY r.id
                    """, REGLEMENT_MAPPER, a.getId()));
        }
        return entetes;
    }

    @Override
    public void annuler(Long id, String motif) {
        jdbcTemplate.update(
                "UPDATE arretes_compte SET statut = 'ANNULE', motif_annulation = ?, updated_at = NOW() WHERE id = ?",
                motif, id);
    }

    @Override
    public boolean existsByReference(String reference) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM arretes_compte WHERE reference = ?", Integer.class, reference);
        return count != null && count > 0;
    }
}
