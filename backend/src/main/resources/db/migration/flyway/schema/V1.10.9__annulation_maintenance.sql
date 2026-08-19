-- Annulation d'une maintenance : motif, auteur et date.
--
-- L'annulation d'une intervention se prononçait sans rien laisser derrière
-- elle : le statut ANNULEE, et c'est tout. Impossible ensuite de dire pourquoi
-- la vidange du mois n'a pas eu lieu, ni qui l'a décidé — alors que la même
-- question, posée sur une recette ou une contravention, trouve sa réponse au
-- registre. L'annulation se motive et se signe ici comme partout ailleurs.

ALTER TABLE maintenances ADD COLUMN IF NOT EXISTS motif_annulation TEXT;
ALTER TABLE maintenances ADD COLUMN IF NOT EXISTS annule_par VARCHAR(255);
ALTER TABLE maintenances ADD COLUMN IF NOT EXISTS annule_le TIMESTAMP;

COMMENT ON COLUMN maintenances.motif_annulation IS
    'Pourquoi l''intervention a été annulée ; obligatoire à l''annulation.';
COMMENT ON COLUMN maintenances.annule_par IS
    'Qui a prononcé l''annulation.';
COMMENT ON COLUMN maintenances.annule_le IS
    'Moment de l''annulation ; NULL tant que l''intervention est au programme.';

-- Reprise de l'existant : les maintenances déjà annulées n'ont ni motif ni
-- auteur à retrouver, mais leur date de dernière modification approche le
-- moment de l'annulation. Mieux vaut cette date que rien du tout.
UPDATE maintenances
   SET annule_le = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)
 WHERE statut = 'ANNULEE' AND annule_le IS NULL;
