-- Pièce d'annulation : les extournes d'un même billet rendu ensemble.
--
-- Annuler un versement recette + cotisation contre-passe ses deux écritures
-- d'un seul geste. Les écritures d'origine gardent leur versement_id et se
-- lisent encore en une ligne ; leurs extournes, elles, n'en héritent pas
-- (V1.11.6 : datées du jour de l'annulation, elles ne décrivent pas le
-- billet) et s'affichaient en deux lignes séparées.
--
-- Cet identifiant, posé sur les seules extournes nées d'une même annulation,
-- dit qu'elles forment une seule pièce. Comme versement_id, il ne change rien
-- à ce que chaque écriture compte : aucun agrégat ne le lit.

ALTER TABLE operations_financieres
    ADD COLUMN IF NOT EXISTS annulation_versement_id UUID;

-- Reprise de l'existant : les extournes d'un même versement passées le même
-- jour sont celles d'une même annulation. L'identifiant est dérivé du couple
-- (versement, jour) pour être stable si la migration est rejouée sur une copie.
UPDATE operations_financieres e
SET annulation_versement_id =
        md5(o.versement_id::text || '|' || e.date_operation::text)::uuid
FROM operations_financieres o
WHERE e.extourne_de_id = o.id
  AND o.versement_id IS NOT NULL
  AND e.annulation_versement_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_operations_financieres_annulation_versement
    ON operations_financieres (annulation_versement_id)
    WHERE annulation_versement_id IS NOT NULL;
