-- ─────────────────────────────────────────────────────────────────────────────
-- Type de maintenance des éléments du catalogue existants.
--
-- La colonne categorie_type_id est créée par V1.12.8. Ce script la renseigne à
-- partir de ce que les gestionnaires ont déjà saisi, puis du nom de l'élément.
-- Ordre de décision, du plus sûr au moins sûr :
--
--   1. Usage établi : l'élément a servi au moins deux fois, toujours sous le
--      même type de maintenance → ce type.
--   2. Nom de l'élément : un mot-clé reconnu (« frein », « filtre », « pneu »…)
--      → le type correspondant. Une utilisation isolée sous un autre type ne
--      l'emporte pas sur le nom (une « Boîte de vitesses » saisie une fois en
--      électricité reste de la mécanique).
--   3. Usage isolé : une seule utilisation, aucun mot-clé → ce type.
--   4. Sinon, l'élément reste sans type, donc commun à tous les types.
--
-- Un élément déjà utilisé sous plusieurs types différents (« Main d'oeuvre »,
-- « Plaquette de frein » saisie en freinage et en mécanique…) reste sans type :
-- lui en imposer un le retirerait des interventions où on l'emploie déjà. Il
-- se précise ensuite dans Paramétrage › Éléments de maintenance.
--
-- Idempotent : seuls les éléments encore sans type sont touchés.
-- ─────────────────────────────────────────────────────────────────────────────

-- Types de maintenance : catégories de la sous-catégorie « Maintenances ».
CREATE TEMP TABLE tmp_types_maintenance ON COMMIT DROP AS
SELECT c.id, c.code
FROM categories_operation c
JOIN sous_categories_operation s ON s.categorie_id = c.id
WHERE s.libelle = 'Maintenances';

-- Utilisations de chaque élément du catalogue, avec le type de l'intervention :
-- celui de la maintenance, ou à défaut celui de la dépense saisie directement
-- en opération.
CREATE TEMP TABLE tmp_usages_elements ON COMMIT DROP AS
SELECT e.catalogue_element_id AS element_id,
       t.id                   AS type_id
FROM elements_maintenance e
LEFT JOIN maintenances m
       ON m.detail_maintenance_id = e.detail_maintenance_id
LEFT JOIN operations_financieres o
       ON o.detail_maintenance_id = e.detail_maintenance_id
      AND m.id IS NULL
JOIN tmp_types_maintenance t
       ON t.id = COALESCE(m.categorie_type_id, o.categorie_id)
WHERE e.catalogue_element_id IS NOT NULL;

CREATE TEMP TABLE tmp_usage_par_element ON COMMIT DROP AS
SELECT element_id,
       MIN(type_id)            AS type_id,
       COUNT(*)                AS nb_usages,
       COUNT(DISTINCT type_id) AS nb_types
FROM tmp_usages_elements
GROUP BY element_id;

-- Mots-clés du nom, dans l'ordre où ils se départagent : « Huile de frein »
-- relève du freinage avant de relever de la vidange, « Huile de moteur » de la
-- vidange avant la mécanique.
CREATE TEMP TABLE tmp_regles_type ON COMMIT DROP AS
SELECT * FROM (VALUES
    (10, '%frein%',              'FREINAGE'),
    (11, '%étrier%',             'FREINAGE'),
    (12, '%etrier%',             'FREINAGE'),
    (13, '%mâchoire%',           'FREINAGE'),
    (14, '%machoire%',           'FREINAGE'),
    (15, '%tambour%',            'FREINAGE'),
    (16, '%maître-cylindre%',    'FREINAGE'),
    (17, '%maitre-cylindre%',    'FREINAGE'),
    (18, '%cylindre de roue%',   'FREINAGE'),
    (20, '%clim%',               'CLIMATISATION'),
    (21, '%compresseur%',        'CLIMATISATION'),
    (30, '%pneu%',               'PNEUMATIQUE'),
    (31, '%jante%',              'PNEUMATIQUE'),
    (32, '%parallélisme%',       'PNEUMATIQUE'),
    (33, '%parallelisme%',       'PNEUMATIQUE'),
    (34, '%équilibrage%',        'PNEUMATIQUE'),
    (35, '%equilibrage%',        'PNEUMATIQUE'),
    (40, '%vidange%',            'VIDANGE'),
    (41, '%filtre%',             'VIDANGE'),
    (42, '%huile%',              'VIDANGE'),
    (50, '%batterie%',           'ELECTRICITE'),
    (51, '%bougie%',             'ELECTRICITE'),
    (52, '%alternateur%',        'ELECTRICITE'),
    (53, '%démarreur%',          'ELECTRICITE'),
    (54, '%demarreur%',          'ELECTRICITE'),
    (55, '%phare%',              'ELECTRICITE'),
    (56, '%feux%',               'ELECTRICITE'),
    (57, '%ampoule%',            'ELECTRICITE'),
    (58, '%électri%',            'ELECTRICITE'),
    (59, '%electri%',            'ELECTRICITE'),
    (60, '%électroni%',          'ELECTRICITE'),
    (61, '%electroni%',          'ELECTRICITE'),
    (62, '%boîte noire%',        'ELECTRICITE'),
    (63, '%fusible%',            'ELECTRICITE'),
    (70, '%peinture%',           'PEINTURE'),
    (71, '%vernis%',             'PEINTURE'),
    (80, '%carrosserie%',        'TOLERIE'),
    (81, '%tôle%',               'TOLERIE'),
    (82, '%vitre%',              'TOLERIE'),
    (83, '%pare-brise%',         'TOLERIE'),
    (84, '%pare-choc%',          'TOLERIE'),
    (85, '%rétroviseur%',        'TOLERIE'),
    (86, '%retroviseur%',        'TOLERIE'),
    (87, '%passage de roue%',    'TOLERIE'),
    (88, '%passage de boue%',    'TOLERIE'),
    (89, '%capot%',              'TOLERIE'),
    (90, '%embray%',             'MECANIQUE'),
    (91, '%boîte de vitesses%',  'MECANIQUE'),
    (92, '%boite de vitesses%',  'MECANIQUE'),
    (93, '%moteur%',             'MECANIQUE'),
    (94, '%courroie%',           'MECANIQUE'),
    (95, '%transmission%',       'MECANIQUE'),
    (96, '%amortisseur%',        'MECANIQUE'),
    (97, '%ressort%',            'MECANIQUE'),
    (98, '%rotule%',             'MECANIQUE'),
    (99, '%roulement%',          'MECANIQUE'),
    (100, '%moyeu%',             'MECANIQUE'),
    (101, '%biellette%',         'MECANIQUE'),
    (102, '%direction%',         'MECANIQUE'),
    (103, '%refroidissement%',   'MECANIQUE'),
    (104, '%radiateur%',         'MECANIQUE'),
    (105, '%cardan%',            'MECANIQUE'),
    (106, '%suspension%',        'MECANIQUE')
) AS r(ordre, motif, code);

-- 1. Usage établi.
UPDATE catalogue_elements_maintenance ce
SET categorie_type_id = u.type_id
FROM tmp_usage_par_element u
WHERE u.element_id = ce.id
  AND u.nb_types = 1
  AND u.nb_usages >= 2
  AND ce.categorie_type_id IS NULL;

-- 2. Nom de l'élément, hors éléments employés sous plusieurs types.
UPDATE catalogue_elements_maintenance ce
SET categorie_type_id = (
        SELECT t.id
        FROM tmp_regles_type r
        JOIN tmp_types_maintenance t ON t.code = r.code
        WHERE lower(ce.libelle) LIKE r.motif
        ORDER BY r.ordre
        LIMIT 1)
WHERE ce.categorie_type_id IS NULL
  AND NOT EXISTS (
        SELECT 1 FROM tmp_usage_par_element u
        WHERE u.element_id = ce.id AND u.nb_types > 1);

-- 3. Usage isolé, quand le nom n'a rien dit.
UPDATE catalogue_elements_maintenance ce
SET categorie_type_id = u.type_id
FROM tmp_usage_par_element u
WHERE u.element_id = ce.id
  AND u.nb_types = 1
  AND ce.categorie_type_id IS NULL;
