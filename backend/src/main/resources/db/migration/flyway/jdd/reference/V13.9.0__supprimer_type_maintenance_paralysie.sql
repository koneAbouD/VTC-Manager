-- ─────────────────────────────────────────────────────────────────────────────
-- Suppression du type de maintenance « Paralysie » (code PARALISE).
--
-- 1. Ses éléments du catalogue passent sous « Pneumatique ».
-- 2. Le type est supprimé avec sa sous-catégorie… sauf si l'historique s'en
--    sert encore (maintenance, opération financière ou facture partenaire) :
--    supprimer casserait ces lignes, et les reclasser changerait après coup la
--    comptabilité passée. Il est alors seulement désactivé : il n'est plus
--    proposé nulle part, l'historique reste intact.
--
-- Migration corrective : V12.1.0 et V12.2.0, qui l'ont créé, sont déjà
-- appliquées et ne sont pas modifiées. Passe après V13.8.0, qui renseigne les
-- types des éléments. Idempotente : sans type PARALISE, elle ne fait rien.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Les éléments de « Paralysie » rejoignent « Pneumatique ».
UPDATE catalogue_elements_maintenance ce
SET categorie_type_id = pneu.id
FROM categories_operation para, categories_operation pneu
WHERE para.code = 'PARALISE'
  AND pneu.code = 'PNEUMATIQUE'
  AND ce.categorie_type_id = para.id;

-- 2. Suppression du type, ou désactivation s'il sert encore à l'historique.
DO $$
DECLARE
    paralysie_id      BIGINT;
    sous_categorie_para BIGINT;
    encore_utilise    BOOLEAN;
BEGIN
    SELECT id INTO paralysie_id FROM categories_operation WHERE code = 'PARALISE';
    IF paralysie_id IS NULL THEN
        RETURN;
    END IF;
    SELECT id INTO sous_categorie_para
    FROM sous_categories_operation WHERE categorie_id = paralysie_id;

    SELECT EXISTS (SELECT 1 FROM maintenances WHERE categorie_type_id = paralysie_id)
        OR EXISTS (SELECT 1 FROM operations_financieres
                   WHERE categorie_id = paralysie_id
                      OR (sous_categorie_para IS NOT NULL
                          AND sous_categorie_id = sous_categorie_para))
        OR EXISTS (SELECT 1 FROM factures_partenaire WHERE categorie_id = paralysie_id)
        OR EXISTS (SELECT 1 FROM catalogue_elements_maintenance
                   WHERE categorie_type_id = paralysie_id)
    INTO encore_utilise;

    IF encore_utilise THEN
        UPDATE sous_categories_operation SET actif = FALSE WHERE categorie_id = paralysie_id;
        UPDATE categories_operation SET actif = FALSE WHERE id = paralysie_id;
        RAISE NOTICE 'Type PARALISE encore utilisé par l''historique : désactivé, non supprimé.';
    ELSE
        DELETE FROM sous_categories_operation WHERE categorie_id = paralysie_id;
        DELETE FROM categories_operation WHERE id = paralysie_id;
    END IF;
END $$;
