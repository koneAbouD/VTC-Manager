-- Rattache au relevé l'écriture qui a soldé son compte d'attente.
--
-- L'imputation d'un écart produit deux écritures : celle qui solde le compte
-- d'attente ouvert par la clôture, et — en cas de perte — celle qui porte
-- l'écart au résultat. Seule la seconde était rattachée au relevé
-- (operation_imputation_id) ; la première ne l'était nulle part.
--
-- Rien ne permettait donc de défaire une imputation : le retrait du relevé la
-- refusait en réclamant qu'on « extourne d'abord les écritures d'imputation »,
-- sans que la moitié d'entre elles soit seulement retrouvable — et sans qu'une
-- extourne, l'aurait-on faite à la main, remette jamais l'écart en attente.
-- L'utilisateur était enfermé, l'erreur pointant vers une action qui n'existait
-- pas.
ALTER TABLE clotures_caisse
    ADD COLUMN IF NOT EXISTS operation_solde_attente_id BIGINT;

COMMENT ON COLUMN clotures_caisse.operation_solde_attente_id IS
    'Écriture qui a soldé le compte d''attente lors de l''imputation ; NULL tant que l''écart n''est pas tranché.';

-- ── Rattrapage des imputations déjà passées ────────────────────────────────
--
-- L'écriture recherchée se reconnaît à son commentaire, composé mot pour mot
-- par l'imputation : « Solde du compte d'attente — écart du {date} — {motif} ».
-- Date, motif et montant réunis suffisent à la désigner sans ambiguïté ; on
-- exige de surcroît qu'elle soit sans compte de trésorerie et qu'elle ne soit
-- pas elle-même une extourne. Une imputation dont l'écriture reste introuvable
-- garde la colonne NULL : le retrait du relevé passera quand même, et
-- l'écriture orpheline restera lisible au journal.
UPDATE clotures_caisse c
   SET operation_solde_attente_id = (
           SELECT o.id
             FROM operations_financieres o
             JOIN categories_operation cat ON cat.id = o.categorie_id
            WHERE o.compte_tresorerie_id IS NULL
              AND o.extourne_de_id IS NULL
              AND o.annule_le IS NULL
              AND cat.code IN ('ECART_CAISSE_ATTENTE_MANQUANT', 'ECART_CAISSE_ATTENTE_EXCEDENT')
              AND o.date_operation = c.date_cloture
              AND o.montant = abs(c.ecart)
              AND o.commentaire = 'Solde du compte d''attente — écart du '
                                  || c.date_cloture || ' — ' || c.imputation_motif
            ORDER BY o.id
            LIMIT 1)
 WHERE c.imputation_statut IN ('PERTE', 'RECOUVREE')
   AND c.operation_solde_attente_id IS NULL
   AND c.imputation_motif IS NOT NULL;
