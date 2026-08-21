-- Restitution partielle d'une cotisation partiellement encaissée.
--
-- Jusqu'ici un arrêté passait la ligne entière en RESTITUEE, quel que soit ce
-- qui restait dû dessus. La ligne sortait alors de v_creances_chauffeurs et la
-- part impayée disparaissait de la balance âgée sans la moindre écriture : le
-- chauffeur ne devait plus rien. On sépare donc les deux faits — ce qui a été
-- encaissé, et ce qui en a été rendu — pour que la dette survive à l'arrêté.
ALTER TABLE lignes_cotisation
    ADD COLUMN IF NOT EXISTS montant_restitue NUMERIC(19, 2) NOT NULL DEFAULT 0;

-- Les arrêtés déjà passés n'ont soldé que des lignes intégralement encaissées :
-- tout leur encaissement a été rendu.
UPDATE lignes_cotisation
SET montant_restitue = montant_encaisse
WHERE statut = 'RESTITUEE'
  AND montant_restitue = 0;

-- Pas de plafond en base : annuler un encaissement déjà restitué ferait
-- retomber montant_encaisse sous montant_restitue, et un CHECK bloquerait
-- l'annulation au lieu de la laisser se dénouer. Le fonds restituable se lit
-- toujours borné à zéro.
ALTER TABLE lignes_cotisation
    DROP CONSTRAINT IF EXISTS chk_lignes_cotisation_restitue;
ALTER TABLE lignes_cotisation
    ADD CONSTRAINT chk_lignes_cotisation_restitue CHECK (montant_restitue >= 0);

COMMENT ON COLUMN lignes_cotisation.montant_restitue IS
    'Part de montant_encaisse déjà rendue par un arrêté de compte. Fonds encore détenu = montant_encaisse - montant_restitue.';
