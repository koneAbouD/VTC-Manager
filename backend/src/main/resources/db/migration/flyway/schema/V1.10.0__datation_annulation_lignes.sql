-- Horodatage de l'annulation des lignes de créance.
--
-- Le motif d'annulation était conservé, mais pas le moment : une ligne annulée
-- portait la seule marque de son statut courant. Impossible dès lors de savoir
-- si, au 31 juillet, elle était encore due — la balance âgée reconstituée à une
-- date passée écartait toute ligne annulée depuis, alors qu'elle figurait bien
-- à l'actif ce jour-là. Les encaissements, eux, étaient déjà datés (annule_le) :
-- on aligne les lignes sur la même convention.

ALTER TABLE lignes_recette    ADD COLUMN IF NOT EXISTS annule_le TIMESTAMP;
ALTER TABLE lignes_cotisation ADD COLUMN IF NOT EXISTS annule_le TIMESTAMP;
ALTER TABLE lignes_penalite   ADD COLUMN IF NOT EXISTS annule_le TIMESTAMP;
ALTER TABLE contraventions    ADD COLUMN IF NOT EXISTS annule_le TIMESTAMP;

COMMENT ON COLUMN lignes_recette.annule_le IS
    'Moment de l''annulation ; NULL tant que la ligne est due.';
COMMENT ON COLUMN lignes_cotisation.annule_le IS
    'Moment de l''annulation ; NULL tant que la ligne est due.';
COMMENT ON COLUMN lignes_penalite.annule_le IS
    'Moment de l''annulation ; NULL tant que la ligne est due.';
COMMENT ON COLUMN contraventions.annule_le IS
    'Moment de l''annulation ; NULL tant que la contravention est due.';

-- Reprise de l'existant : la date de dernière modification est la meilleure
-- approximation disponible du moment de l'annulation. À défaut — enregistrement
-- jamais retouché depuis sa création — on retient sa création, jamais NULL :
-- une ligne annulée sans date resterait due à perpétuité dans les états passés.
UPDATE lignes_recette
   SET annule_le = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)
 WHERE statut = 'ANNULEE' AND annule_le IS NULL;

UPDATE lignes_cotisation
   SET annule_le = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)
 WHERE statut = 'ANNULEE' AND annule_le IS NULL;

UPDATE lignes_penalite
   SET annule_le = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)
 WHERE statut = 'ANNULEE' AND annule_le IS NULL;

UPDATE contraventions
   SET annule_le = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)
 WHERE statut = 'ANNULE' AND annule_le IS NULL;
