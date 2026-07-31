-- La dette peut désormais naître d'une intervention, pas seulement d'une
-- facture saisie à la main.
--
-- Jusqu'ici, terminer une maintenance créait aussitôt une dépense payée : le
-- travail non encore réglé n'existait nulle part, et le garage à qui l'on
-- devait 200 000 F n'apparaissait dans aucun passif. Une maintenance terminée
-- « à payer » engendre maintenant une dette partenaire, soldée par son
-- règlement — exactement comme une facture reçue.
--
-- Un même chantier pouvant mêler plusieurs prestataires (le garage répare, un
-- autre fournit les pièces), la ligne d'élément porte son propre partenaire :
-- la complétion produit alors une dette par partenaire, chacune du montant de
-- ses lignes.

-- Partenaire de la ligne. Null = celui de l'intervention (cas courant : un
-- seul prestataire fait tout).
ALTER TABLE elements_maintenance ADD COLUMN IF NOT EXISTS partenaire_id BIGINT;
ALTER TABLE elements_maintenance DROP CONSTRAINT IF EXISTS fk_elements_maintenance_partenaire;
ALTER TABLE elements_maintenance
    ADD CONSTRAINT fk_elements_maintenance_partenaire
        FOREIGN KEY (partenaire_id) REFERENCES partenaires(id);
CREATE INDEX IF NOT EXISTS idx_elements_maintenance_partenaire
    ON elements_maintenance(partenaire_id)
    WHERE partenaire_id IS NOT NULL;

-- Intervention à l'origine de la dette. Sert à remonter de l'échéancier à la
-- maintenance, et à refuser qu'une même intervention soit facturée deux fois.
ALTER TABLE factures_partenaire ADD COLUMN IF NOT EXISTS maintenance_id BIGINT;
ALTER TABLE factures_partenaire DROP CONSTRAINT IF EXISTS fk_factures_partenaire_maintenance;
ALTER TABLE factures_partenaire
    ADD CONSTRAINT fk_factures_partenaire_maintenance
        FOREIGN KEY (maintenance_id) REFERENCES maintenances(id);
CREATE INDEX IF NOT EXISTS idx_factures_partenaire_maintenance
    ON factures_partenaire(maintenance_id)
    WHERE maintenance_id IS NOT NULL;
