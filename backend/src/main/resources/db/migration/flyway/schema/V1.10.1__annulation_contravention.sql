-- Annulation d'une contravention : motif et auteur.
--
-- Le statut ANNULE existait dans le modèle sans qu'aucun chemin ne l'atteigne :
-- une contravention saisie à tort ne pouvait être que supprimée, effaçant du
-- même coup la créance qu'elle avait portée. L'annulation la conserve au
-- registre — datée (V1.10.0), motivée et signée — comme toute autre écriture.

ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS motif_annulation TEXT;
ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS annule_par VARCHAR(255);

COMMENT ON COLUMN contraventions.motif_annulation IS
    'Pourquoi la contravention a été annulée ; obligatoire à l''annulation.';
COMMENT ON COLUMN contraventions.annule_par IS
    'Qui a prononcé l''annulation.';
