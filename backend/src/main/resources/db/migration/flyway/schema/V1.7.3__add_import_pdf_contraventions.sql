-- Import des relevés de contraventions de l'État (Ministère des Transports / CGI)
-- par PDF : on étend la table `contraventions` existante des champs propres au
-- relevé et au rattachement automatique du chauffeur via le programme de travail.

ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS numero_contravention VARCHAR(50);
ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS heure_infraction      TIME;
ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS vitesse_relevee       INT;
ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS code_infraction       VARCHAR(20);
ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS document_source_path  VARCHAR(512);
ALTER TABLE contraventions ADD COLUMN IF NOT EXISTS statut_rattachement   VARCHAR(20);

-- Unicité du numéro de contravention (clé anti-doublon face aux relevés cumulatifs).
-- Les saisies manuelles n'ont pas de numéro (NULL) : un index partiel autorise
-- plusieurs NULL tout en garantissant l'unicité des numéros importés.
CREATE UNIQUE INDEX IF NOT EXISTS uk_contraventions_numero
    ON contraventions(numero_contravention)
    WHERE numero_contravention IS NOT NULL;
