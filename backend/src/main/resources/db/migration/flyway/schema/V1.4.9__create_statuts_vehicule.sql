-- Table de référence des statuts de véhicule.
-- Le code correspond aux valeurs de l'enum VehiculeStatus ; la colonne
-- vehicules.statut (VARCHAR) y fait référence par ce code. Cette table porte
-- uniquement les métadonnées d'affichage (libellé, signification, couleur)
-- pilotées en base, sans contrainte de clé étrangère pour rester non intrusive.
CREATE TABLE IF NOT EXISTS statuts_vehicule (
    code          VARCHAR(30)  PRIMARY KEY,
    libelle       VARCHAR(100) NOT NULL,
    signification VARCHAR(255),
    couleur       VARCHAR(20)  NOT NULL,
    ordre         INT          NOT NULL DEFAULT 0,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);
