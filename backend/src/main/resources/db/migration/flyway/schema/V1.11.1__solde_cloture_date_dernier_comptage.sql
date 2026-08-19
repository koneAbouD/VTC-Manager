-- Jusqu'où le solde archivé d'un compte est attesté par un comptage réel.
--
-- La clôture d'un mois archive la trésorerie arrêtée au dernier jour du mois,
-- mais ne réclame qu'un comptage tombant *quelque part* dans ce mois : un
-- comptage le 3 valide les 31 jours. Le solde publié pouvait donc porter sur
-- une somme que personne n'avait vérifiée depuis quatre semaines, sans que rien
-- ne le dise.
--
-- Plutôt que de durcir l'exigence — au risque d'enfermer une exploitation dont
-- les saisies arrivent en retard —, la photo dit désormais ce qu'elle vaut :
-- le lecteur voit le solde, sa date d'arrêté, et la date du dernier comptage
-- qui l'atteste. Il juge lui-même de l'écart entre les deux.
--
-- NULL sur les photos déjà prises, et sur un compte jamais compté : la lecture
-- affiche alors « aucun comptage » plutôt qu'une date inventée.
ALTER TABLE soldes_cloture_periode
    ADD COLUMN IF NOT EXISTS date_dernier_comptage DATE;

COMMENT ON COLUMN soldes_cloture_periode.date_dernier_comptage IS
    'Dernier comptage non retiré de ce compte à la date d''arrêté ; NULL si aucun.';
