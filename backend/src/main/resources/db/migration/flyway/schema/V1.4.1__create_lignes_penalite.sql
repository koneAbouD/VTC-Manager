CREATE TABLE IF NOT EXISTS lignes_penalite (
    id                           BIGSERIAL      PRIMARY KEY,
    vehicule_id                  BIGINT         NOT NULL,
    chauffeur_id                 BIGINT         NOT NULL,
    penalite_template_id         BIGINT,
    type_penalite                VARCHAR(50)    NOT NULL,
    type_sanction                VARCHAR(50)    NOT NULL,
    montant                      NUMERIC(19, 2) NOT NULL DEFAULT 0,
    montant_encaisse             NUMERIC(19, 2) NOT NULL DEFAULT 0,
    duree_sanction_secondes      INT,
    duree_immobilisation_minutes INT,
    date_debut_immobilisation    TIMESTAMP,
    date_fin_immobilisation      TIMESTAMP,
    date_generation              DATE           NOT NULL,
    date_faute                   DATE,
    ligne_recette_id             BIGINT,
    statut                       VARCHAR(30)    NOT NULL DEFAULT 'EN_ATTENTE',
    commentaire                  TEXT,
    created_at                   TIMESTAMP,
    updated_at                   TIMESTAMP,
    CONSTRAINT fk_lp_vehicule    FOREIGN KEY (vehicule_id)           REFERENCES vehicules(id),
    CONSTRAINT fk_lp_chauffeur   FOREIGN KEY (chauffeur_id)          REFERENCES chauffeurs(id),
    CONSTRAINT fk_lp_template    FOREIGN KEY (penalite_template_id)  REFERENCES penalite_template(id),
    CONSTRAINT fk_lp_recette     FOREIGN KEY (ligne_recette_id)      REFERENCES lignes_recette(id),
    CONSTRAINT chk_lp_sanction   CHECK (type_sanction IN ('BUZZER', 'AMENDE', 'AVERTISSEMENT', 'IMMOBILISATION')),
    CONSTRAINT chk_lp_statut     CHECK (statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSEE', 'ENCAISSEE',
                                                    'EXECUTEE', 'NOTIFIEE', 'EN_COURS', 'LEVEE', 'ANNULEE')),
    CONSTRAINT chk_lp_montant    CHECK (montant_encaisse >= 0)
);

CREATE INDEX IF NOT EXISTS idx_lp_vehicule  ON lignes_penalite(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_lp_chauffeur ON lignes_penalite(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_lp_statut    ON lignes_penalite(statut);
CREATE INDEX IF NOT EXISTS idx_lp_sanction  ON lignes_penalite(type_sanction);
CREATE INDEX IF NOT EXISTS idx_lp_faute     ON lignes_penalite(date_faute);
