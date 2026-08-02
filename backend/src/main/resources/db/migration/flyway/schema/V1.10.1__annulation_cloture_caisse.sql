-- Annulation d'un relevé de caisse erroné.
--
-- Un comptage saisi à la mauvaise date enfermait l'utilisateur : la série des
-- comptages devant rester chronologique, plus aucun relevé antérieur ne pouvait
-- être enregistré, et la clôture du mois concerné devenait impossible à
-- satisfaire. Un procès-verbal de comptage erroné ne se supprime pas — il
-- s'annule, avec son motif et son auteur, et reste au dossier.

ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS annule_le        TIMESTAMP;
ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS annule_par       VARCHAR(255);
ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS motif_annulation TEXT;

COMMENT ON COLUMN clotures_caisse.annule_le IS
    'Moment de l''annulation du relevé ; NULL tant qu''il fait foi.';

-- L'unicité ne vaut plus que pour les relevés en vigueur : une journée annulée
-- doit pouvoir être recomptée, sans quoi l'annulation ne servirait à rien.
ALTER TABLE clotures_caisse DROP CONSTRAINT IF EXISTS uk_clotures_caisse_compte_date;

CREATE UNIQUE INDEX IF NOT EXISTS uk_clotures_caisse_compte_date_actives
    ON clotures_caisse (compte_id, date_cloture)
 WHERE annule_le IS NULL;
