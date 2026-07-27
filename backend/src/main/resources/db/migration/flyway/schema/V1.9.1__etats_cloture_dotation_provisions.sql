-- Dotation aux provisions sur créances dans la photo de clôture.
--
-- La provision corrigeait l'actif au bilan sans que le résultat n'en porte la
-- charge : les deux états ne se répondaient pas. La dotation d'un mois est la
-- VARIATION du stock de provision (photo du mois précédent → stock à la
-- clôture) ; une reprise, quand les créances rentrent, l'améliore.
ALTER TABLE etats_cloture_periode
    ADD COLUMN IF NOT EXISTS dotation_provisions NUMERIC(19, 2) NOT NULL DEFAULT 0;
