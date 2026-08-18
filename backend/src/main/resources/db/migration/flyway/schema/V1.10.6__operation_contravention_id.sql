-- Rattache l'écriture à la contravention qu'elle règle.
--
-- L'encaissement d'un remboursement de contravention créait une opération
-- sans lien vers la contravention : en annulant l'écriture, la contravention
-- restait PAYE alors que le chauffeur n'avait plus rien versé — la créance
-- disparaissait des relances sans avoir été honorée. Le lien permet de la
-- repositionner à son état antérieur (EN_ATTENTE ou PARTIELLEMENT_PAYE)
-- comme le font déjà les lignes de recette, de cotisation et de pénalité.
--
-- Les écritures antérieures restent sans lien : rien ne permet de les
-- rattacher après coup de façon sûre. Elles conservent l'ancien comportement.
ALTER TABLE operations_financieres ADD COLUMN IF NOT EXISTS contravention_id BIGINT;
ALTER TABLE operations_financieres DROP CONSTRAINT IF EXISTS fk_operations_contravention;
ALTER TABLE operations_financieres
    ADD CONSTRAINT fk_operations_contravention
        FOREIGN KEY (contravention_id) REFERENCES contraventions(id);
CREATE INDEX IF NOT EXISTS idx_operations_contravention
    ON operations_financieres(contravention_id)
    WHERE contravention_id IS NOT NULL;
