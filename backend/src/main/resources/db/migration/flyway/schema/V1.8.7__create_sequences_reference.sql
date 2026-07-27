-- Numérotation continue des pièces comptables, par journal et par exercice.
--
-- Les références étaient construites à partir de l'horloge
-- (« ENC-2026-<millisecondes> ») : ni continues, ni chronologiquement fiables,
-- et deux saisies dans la même milliseconde violaient l'unicité. Un compteur
-- par (journal, exercice) rend la série vérifiable : un trou se voit.
CREATE TABLE IF NOT EXISTS sequences_reference (
    journal        VARCHAR(10) NOT NULL,
    exercice       INTEGER     NOT NULL,
    dernier_numero BIGINT      NOT NULL DEFAULT 0,
    CONSTRAINT pk_sequences_reference PRIMARY KEY (journal, exercice),
    CONSTRAINT chk_sequences_reference_numero CHECK (dernier_numero >= 0)
);

-- Reprise de l'existant : chaque compteur démarre au-delà du nombre de pièces
-- déjà émises sur l'exercice, pour ne jamais rejouer une référence libérée.
INSERT INTO sequences_reference (journal, exercice, dernier_numero)
SELECT j.journal, EXTRACT(YEAR FROM o.date_operation)::INTEGER, COUNT(*)
FROM operations_financieres o
CROSS JOIN LATERAL (SELECT COALESCE(SPLIT_PART(o.reference, '-', 1), 'OPE') AS journal) j
WHERE o.reference IS NOT NULL
GROUP BY j.journal, EXTRACT(YEAR FROM o.date_operation)
ON CONFLICT (journal, exercice) DO NOTHING;
