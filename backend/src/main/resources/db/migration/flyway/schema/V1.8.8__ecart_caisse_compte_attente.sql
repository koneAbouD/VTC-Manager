-- Écart de caisse : compte d'attente avant imputation.
--
-- Un manquant partait directement en charge et un excédent en produit, comme si
-- l'affaire était réglée le jour du comptage. Comptablement, un écart constaté
-- est d'abord une somme à éclaircir : il transite par un compte d'attente
-- (HORS_RESULTAT, donc sans effet sur le résultat), puis une décision explicite
-- l'impute — en perte pour l'entreprise, ou en créance sur le responsable.
INSERT INTO categories_operation (code, libelle, type_operation, actif, nature_resultat) VALUES
    ('ECART_CAISSE_ATTENTE_MANQUANT', 'Écart de caisse à imputer (manquant)', 'DEPENSE', TRUE, 'HORS_RESULTAT'),
    ('ECART_CAISSE_ATTENTE_EXCEDENT', 'Écart de caisse à imputer (excédent)', 'REVENU',  TRUE, 'HORS_RESULTAT')
ON CONFLICT (code) DO NOTHING;

-- Le responsable désigné du comptage, et le suivi de l'imputation de l'écart.
ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS responsable            VARCHAR(255);
ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS imputation_statut      VARCHAR(20);
ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS imputation_motif       TEXT;
ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS imputee_le             TIMESTAMP;
ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS imputee_par            VARCHAR(255);
ALTER TABLE clotures_caisse ADD COLUMN IF NOT EXISTS operation_imputation_id BIGINT;

ALTER TABLE clotures_caisse
    DROP CONSTRAINT IF EXISTS fk_clotures_caisse_operation_imputation;
ALTER TABLE clotures_caisse
    ADD CONSTRAINT fk_clotures_caisse_operation_imputation
    FOREIGN KEY (operation_imputation_id) REFERENCES operations_financieres(id);

ALTER TABLE clotures_caisse
    DROP CONSTRAINT IF EXISTS chk_clotures_caisse_imputation_statut;
ALTER TABLE clotures_caisse
    ADD CONSTRAINT chk_clotures_caisse_imputation_statut
    CHECK (imputation_statut IS NULL
           OR imputation_statut IN ('EN_ATTENTE', 'PERTE', 'RECOUVREE'));

-- Les clôtures déjà enregistrées avec un écart ont imputé directement en
-- charge/produit : elles sont considérées comme soldées, pas en attente.
UPDATE clotures_caisse
   SET imputation_statut = CASE WHEN ecart = 0 THEN NULL ELSE 'PERTE' END
 WHERE imputation_statut IS NULL;
