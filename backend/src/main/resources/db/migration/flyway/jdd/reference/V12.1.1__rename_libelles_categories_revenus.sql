-- ─────────────────────────────────────────────────────────────────────────────
-- Renomme les libellés des catégories d'encaissement (REVENU) vers une forme
-- courte. Migration corrective : la V12.1.0 étant déjà appliquée, on ne la
-- modifie pas — on ajuste ici les libellés pour les bases existantes ET neuves.
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE categories_operation SET libelle = 'Recette'    WHERE code = 'ENCAISSEMENT_RECETTES';
UPDATE categories_operation SET libelle = 'Cotisation' WHERE code = 'ENCAISSEMENT_COTISATIONS';
UPDATE categories_operation SET libelle = 'Pénalité'   WHERE code = 'ENCAISSEMENT_PENALITES';
