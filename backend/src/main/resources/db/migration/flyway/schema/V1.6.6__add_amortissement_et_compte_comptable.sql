-- Immobilisations : prix d'achat + durée d'amortissement linéaire (60 mois
-- par défaut). Permet la valeur nette comptable au bilan de gestion et la
-- ligne de dotation du compte de résultat.
ALTER TABLE vehicules
    ADD COLUMN IF NOT EXISTS prix_achat NUMERIC(19, 2),
    ADD COLUMN IF NOT EXISTS duree_amortissement_mois INT NOT NULL DEFAULT 60;

-- Mapping vers le plan comptable (SYSCOHADA) pour l'export vers le cabinet.
-- Renseigné par l'admin ; l'export laisse la colonne vide sinon.
ALTER TABLE categories_operation
    ADD COLUMN IF NOT EXISTS compte_comptable VARCHAR(10);
