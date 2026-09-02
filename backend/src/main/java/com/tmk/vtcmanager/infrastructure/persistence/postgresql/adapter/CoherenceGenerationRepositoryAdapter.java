package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.coherence.ConflitChauffeurJour;
import com.tmk.vtcmanager.application.ports.persistence.CoherenceGenerationRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;

@Component
@RequiredArgsConstructor
public class CoherenceGenerationRepositoryAdapter implements CoherenceGenerationRepository {

    private final JdbcTemplate jdbcTemplate;

    /**
     * Les lignes que la génération vient de créer peuvent n'exister encore que
     * dans la session JPA : {@link JdbcTemplate} interroge la base directement
     * et ne les verrait pas. On vide donc la session avant de lire — sans quoi
     * le contrôle passerait précisément à côté de ce qu'il cherche.
     */
    @PersistenceContext
    private EntityManager entityManager;

    /**
     * L'UNION dédoublonne d'elle-même : un chauffeur qui a, sur un même
     * véhicule, une recette et trois cotisations n'y figure qu'une fois. Ne
     * ressortent donc que les couples chauffeur/véhicule distincts, et le
     * HAVING ne retient que les chauffeurs qui en ont plusieurs.
     */
    @Override
    @Transactional
    public List<ConflitChauffeurJour> chauffeursSurPlusieursVehicules(LocalDate debut, LocalDate fin) {
        entityManager.flush();
        return jdbcTemplate.query("""
                SELECT t.jour                                   AS jour,
                       c.id                                     AS chauffeur_id,
                       TRIM(COALESCE(c.prenom, '') || ' ' || COALESCE(c.nom, '')) AS chauffeur_nom,
                       STRING_AGG(v.immatriculation, ',' ORDER BY v.immatriculation) AS immatriculations
                FROM (
                    SELECT date_recette AS jour, chauffeur_id, vehicule_id
                    FROM lignes_recette
                    WHERE date_recette BETWEEN ? AND ? AND statut <> 'ANNULEE'
                    UNION
                    SELECT date_cotisation, chauffeur_id, vehicule_id
                    FROM lignes_cotisation
                    WHERE date_cotisation BETWEEN ? AND ? AND statut <> 'ANNULEE'
                ) t
                JOIN chauffeurs c ON c.id = t.chauffeur_id
                JOIN vehicules  v ON v.id = t.vehicule_id
                GROUP BY t.jour, c.id, c.prenom, c.nom
                HAVING COUNT(DISTINCT t.vehicule_id) > 1
                ORDER BY t.jour DESC, chauffeur_nom
                """,
                (rs, i) -> new ConflitChauffeurJour(
                        rs.getObject("jour", java.sql.Date.class).toLocalDate(),
                        rs.getLong("chauffeur_id"),
                        rs.getString("chauffeur_nom"),
                        immatriculations(rs.getString("immatriculations"))),
                debut, fin, debut, fin);
    }

    private static List<String> immatriculations(String agregat) {
        if (agregat == null || agregat.isBlank()) return List.of();
        return Arrays.stream(agregat.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();
    }
}
