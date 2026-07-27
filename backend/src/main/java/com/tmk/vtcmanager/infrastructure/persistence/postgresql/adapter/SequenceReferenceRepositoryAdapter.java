package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.ports.persistence.SequenceReferenceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Compteur de pièces en base.
 *
 * <p>L'{@code INSERT … ON CONFLICT DO UPDATE … RETURNING} incrémente et lit en
 * une seule instruction : la ligne (journal, exercice) est verrouillée le temps
 * de l'opération, deux saisies simultanées ne peuvent donc pas obtenir le même
 * numéro.
 *
 * <p>{@code REQUIRES_NEW} : le numéro est consommé même si la transaction
 * appelante échoue ensuite. On préfère un trou dans la numérotation — anomalie
 * visible et explicable — à un doublon, qui rendrait deux pièces
 * indiscernables.
 */
@Repository
@RequiredArgsConstructor
public class SequenceReferenceRepositoryAdapter implements SequenceReferenceRepository {

    private final JdbcTemplate jdbcTemplate;

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public long suivant(String journal, int exercice) {
        Long numero = jdbcTemplate.queryForObject("""
                INSERT INTO sequences_reference (journal, exercice, dernier_numero)
                VALUES (?, ?, 1)
                ON CONFLICT (journal, exercice)
                DO UPDATE SET dernier_numero = sequences_reference.dernier_numero + 1
                RETURNING dernier_numero
                """, Long.class, journal, exercice);
        return numero != null ? numero : 1L;
    }
}
