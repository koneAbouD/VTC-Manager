-- Application chauffeur (self-service) : lien vers le compte Keycloak + codes OTP WhatsApp.

-- 1. Lien Chauffeur -> utilisateur Keycloak (nullable : tous les chauffeurs n'ont pas de compte)
ALTER TABLE chauffeurs
    ADD COLUMN keycloak_user_id VARCHAR(36);

CREATE UNIQUE INDEX ux_chauffeurs_keycloak_user_id
    ON chauffeurs (keycloak_user_id)
    WHERE keycloak_user_id IS NOT NULL;

-- 2. Codes OTP (authentification passwordless par WhatsApp)
--    Le code n'est jamais stocké en clair : seul son hash est persisté.
CREATE TABLE otp_codes (
    id           BIGSERIAL PRIMARY KEY,
    telephone    VARCHAR(30)  NOT NULL,
    code_hash    VARCHAR(255) NOT NULL,
    expires_at   TIMESTAMP    NOT NULL,
    tentatives   INTEGER      NOT NULL DEFAULT 0,
    consomme     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_otp_codes_telephone ON otp_codes (telephone);
CREATE INDEX ix_otp_codes_expires_at ON otp_codes (expires_at);
