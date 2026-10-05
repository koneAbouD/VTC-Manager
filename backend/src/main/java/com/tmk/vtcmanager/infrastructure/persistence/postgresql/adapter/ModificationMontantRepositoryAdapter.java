package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.modification.ModificationMontant;
import com.tmk.vtcmanager.application.ports.persistence.ModificationMontantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class ModificationMontantRepositoryAdapter implements ModificationMontantRepository {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void enregistrer(ModificationMontant m) {
        jdbcTemplate.update("""
                INSERT INTO modifications_montant
                    (document_type, document_id, ancien_montant, nouveau_montant, motif, created_by, created_at)
                VALUES (?, ?, ?, ?, ?, ?, NOW())
                """,
                m.document().name(), m.documentId(), m.ancienMontant(), m.nouveauMontant(),
                m.motif(), m.createdBy());
    }
}
