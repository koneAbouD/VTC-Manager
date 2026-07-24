-- Module « Paramètres généraux » : table clé-valeur pour les réglages globaux
-- de l'application (extensible). Premier usage : la durée d'amortissement des
-- véhicules par défaut (voir le seed en jdd/reference).
CREATE TABLE IF NOT EXISTS parametres_generaux (
    cle         VARCHAR(60) PRIMARY KEY,
    valeur      VARCHAR(255) NOT NULL,
    libelle     VARCHAR(120) NOT NULL,
    description VARCHAR(500),
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP
);

-- La durée d'amortissement devient paramétrable globalement : la colonne par
-- véhicule ne sert plus que d'override optionnel (NULL = suit le paramètre
-- global). On retire donc le NOT NULL / DEFAULT, et on remet à NULL les valeurs
-- historiques laissées au défaut 60 (jamais saisies explicitement : la durée
-- n'était pas exposée à l'UI), afin qu'elles suivent désormais le global.
ALTER TABLE vehicules
    ALTER COLUMN duree_amortissement_mois DROP DEFAULT,
    ALTER COLUMN duree_amortissement_mois DROP NOT NULL;

UPDATE vehicules SET duree_amortissement_mois = NULL WHERE duree_amortissement_mois = 60;
