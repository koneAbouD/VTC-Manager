-- Piste d'audit des écritures financières.
--
-- Trois manques comblés ici :
--   1. l'auteur : une écriture qui touche l'argent doit être rattachable à
--      quelqu'un (created_by / updated_by, alimentés depuis le jeton Keycloak) ;
--   2. l'extourne : annuler ne doit plus faire disparaître l'écriture d'origine,
--      mais lui opposer une contre-passation datée du jour (extourne_de_id,
--      montant négatif, même type et même catégorie que l'origine) ;
--   3. le motif et l'auteur de l'annulation, sur l'écriture d'origine comme sur
--      l'encaissement sous-jacent, qui n'est plus supprimé mais marqué annulé.

-- ── 1. Auteur des écritures ────────────────────────────────────────────────
ALTER TABLE operations_financieres  ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE operations_financieres  ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE encaissements           ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE encaissements           ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE encaissements_cotisation ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE encaissements_cotisation ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE encaissements_penalite  ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE encaissements_penalite  ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE clotures_caisse         ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE clotures_caisse         ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE clotures_periode        ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE clotures_periode        ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE transferts_tresorerie   ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE transferts_tresorerie   ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);

-- Les écritures antérieures à cette migration n'ont pas d'auteur connu : on le
-- dit explicitement plutôt que de laisser un NULL ambigu.
UPDATE operations_financieres   SET created_by = 'inconnu' WHERE created_by IS NULL;
UPDATE encaissements            SET created_by = 'inconnu' WHERE created_by IS NULL;
UPDATE encaissements_cotisation SET created_by = 'inconnu' WHERE created_by IS NULL;
UPDATE encaissements_penalite   SET created_by = 'inconnu' WHERE created_by IS NULL;
UPDATE clotures_caisse          SET created_by = 'inconnu' WHERE created_by IS NULL;
UPDATE clotures_periode         SET created_by = 'inconnu' WHERE created_by IS NULL;
UPDATE transferts_tresorerie    SET created_by = 'inconnu' WHERE created_by IS NULL;

-- ── 2. Extourne et traçabilité de l'annulation ─────────────────────────────
-- extourne_de_id porte la contre-passation : montant négatif, même type et même
-- catégorie que l'origine. Tous les agrégats existants (soldes, cascade du
-- compte de résultat, rapports) restent donc justes sans être modifiés — le
-- couple origine + extourne s'annule arithmétiquement.
ALTER TABLE operations_financieres ADD COLUMN IF NOT EXISTS extourne_de_id   BIGINT;
ALTER TABLE operations_financieres ADD COLUMN IF NOT EXISTS motif_annulation TEXT;
ALTER TABLE operations_financieres ADD COLUMN IF NOT EXISTS annule_par       VARCHAR(255);
ALTER TABLE operations_financieres ADD COLUMN IF NOT EXISTS annule_le        TIMESTAMP;

ALTER TABLE operations_financieres
    DROP CONSTRAINT IF EXISTS fk_operations_financieres_extourne;
ALTER TABLE operations_financieres
    ADD CONSTRAINT fk_operations_financieres_extourne
    FOREIGN KEY (extourne_de_id) REFERENCES operations_financieres(id);

-- Une écriture ne s'extourne qu'une fois.
CREATE UNIQUE INDEX IF NOT EXISTS ux_operations_financieres_extourne_de
    ON operations_financieres(extourne_de_id) WHERE extourne_de_id IS NOT NULL;

-- ── 3. Encaissements : marqués annulés, plus jamais supprimés ──────────────
ALTER TABLE encaissements            ADD COLUMN IF NOT EXISTS annule_le        TIMESTAMP;
ALTER TABLE encaissements            ADD COLUMN IF NOT EXISTS annule_par       VARCHAR(255);
ALTER TABLE encaissements            ADD COLUMN IF NOT EXISTS motif_annulation TEXT;
ALTER TABLE encaissements_cotisation ADD COLUMN IF NOT EXISTS annule_le        TIMESTAMP;
ALTER TABLE encaissements_cotisation ADD COLUMN IF NOT EXISTS annule_par       VARCHAR(255);
ALTER TABLE encaissements_cotisation ADD COLUMN IF NOT EXISTS motif_annulation TEXT;
ALTER TABLE encaissements_penalite   ADD COLUMN IF NOT EXISTS annule_le        TIMESTAMP;
ALTER TABLE encaissements_penalite   ADD COLUMN IF NOT EXISTS annule_par       VARCHAR(255);
ALTER TABLE encaissements_penalite   ADD COLUMN IF NOT EXISTS motif_annulation TEXT;

-- Le recalcul des lignes ne doit plus voir les encaissements annulés : ces
-- index servent les SUM filtrés du recalcul.
CREATE INDEX IF NOT EXISTS idx_encaissements_actifs
    ON encaissements(ligne_recette_id) WHERE annule_le IS NULL;
CREATE INDEX IF NOT EXISTS idx_encaissements_cotisation_actifs
    ON encaissements_cotisation(ligne_cotisation_id) WHERE annule_le IS NULL;
CREATE INDEX IF NOT EXISTS idx_encaissements_penalite_actifs
    ON encaissements_penalite(ligne_penalite_id) WHERE annule_le IS NULL;
