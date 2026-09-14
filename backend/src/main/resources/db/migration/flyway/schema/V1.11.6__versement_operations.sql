-- Pièce de caisse : un même versement pour la recette et la cotisation du jour.
--
-- Le chauffeur remet le plus souvent un seul billet pour sa recette et sa
-- cotisation. Le journal en garde pourtant deux écritures, et il doit les
-- garder : la recette est un produit, la cotisation un dépôt détenu pour le
-- chauffeur (HORS_RESULTAT, voir V13.1.0). Les fondre fausserait le compte de
-- résultat dans un sens ou dans l'autre.
--
-- Ce qui manquait, c'est de savoir qu'elles forment un seul versement. Cet
-- identifiant commun le dit, sans rien changer à ce que chacune compte :
-- résultat, export, bilan, fonds de cotisation et clôtures ne le lisent pas.
--
-- Invariant tenu par les use cases : un identifiant renseigné désigne des
-- écritures qui décrivent encore le même billet — même jour, même chauffeur.
-- Redater l'une ou la réaffecter les en détache toutes. Une extourne n'en
-- hérite jamais : elle est datée du jour de l'annulation, pas du versement.

ALTER TABLE operations_financieres
    ADD COLUMN IF NOT EXISTS versement_id UUID;

-- Lu par versement (détail, reçu) : l'immense majorité des écritures n'en
-- porte pas, l'index partiel ne paie que pour celles qui en ont un.
CREATE INDEX IF NOT EXISTS idx_operations_financieres_versement
    ON operations_financieres (versement_id)
    WHERE versement_id IS NOT NULL;
