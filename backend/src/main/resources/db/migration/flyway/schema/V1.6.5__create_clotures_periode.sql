-- Clôture mensuelle : fige une période comptable. Aucune opération,
-- annulation ou transfert daté dans (ou avant) une période clôturée ne
-- peut plus être enregistré — c'est ce qui rend les états à date passée
-- fiables (bilan, compte de résultat, export comptable).
CREATE TABLE IF NOT EXISTS clotures_periode (
    id           BIGSERIAL PRIMARY KEY,
    annee        INT       NOT NULL,
    mois         INT       NOT NULL,
    date_cloture TIMESTAMP NOT NULL,
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP,
    CONSTRAINT uk_clotures_periode UNIQUE (annee, mois),
    CONSTRAINT chk_clotures_mois   CHECK (mois BETWEEN 1 AND 12)
);
