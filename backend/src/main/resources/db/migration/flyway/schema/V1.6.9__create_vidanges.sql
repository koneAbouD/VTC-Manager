-- Historique des vidanges d'un véhicule : une ligne par vidange effectuée.
-- La vidange la plus récente (date_vidange, puis id) porte à la fois l'événement
-- réalisé (date + kilométrage) et la cible de la prochaine vidange
-- (date_prochaine_vidange + kilometrage_prochaine_vidange, facultatives).
-- L'onglet « Infos » du véhicule lit la dernière ligne ; la page d'historique
-- liste toutes les lignes du véhicule par ordre antéchronologique.
CREATE TABLE IF NOT EXISTS vidanges (
    id                            BIGSERIAL PRIMARY KEY,
    vehicule_id                   BIGINT    NOT NULL REFERENCES vehicules (id) ON DELETE CASCADE,
    date_vidange                  DATE      NOT NULL,
    kilometrage_vidange           INTEGER   NOT NULL,
    date_prochaine_vidange        DATE,
    kilometrage_prochaine_vidange INTEGER,
    commentaire                   VARCHAR(500),
    created_at                    TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at                    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Accès à l'historique d'un véhicule et à sa dernière vidange (tri antéchronologique).
CREATE INDEX IF NOT EXISTS idx_vidanges_vehicule
    ON vidanges (vehicule_id, date_vidange DESC, id DESC);
