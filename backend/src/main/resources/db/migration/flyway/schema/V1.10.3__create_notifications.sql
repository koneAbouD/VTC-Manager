-- Notifications push (Firebase Cloud Messaging) et centre de notifications.
--
-- Deux tables, deux rôles distincts :
--
--   • device_tokens : à qui pousser. Un enregistrement = un couple
--     (appareil, compte connecté dessus).
--   • notifications : ce qui a été notifié. C'est l'historique consultable
--     dans l'application — une notification balayée sur l'écran d'accueil du
--     téléphone reste lisible ici, ce qui compte pour des alertes financières.
--
-- L'ancrage se fait sur l'identifiant Keycloak (« sub » du jeton) et non sur
-- une clé étrangère vers chauffeurs : les gestionnaires n'existent que dans
-- Keycloak, sans ligne en base. Le « sub » est le seul identifiant commun aux
-- deux populations, et c'est déjà celui que résout CurrentChauffeurResolver.

CREATE TABLE IF NOT EXISTS device_tokens (
    id               BIGSERIAL    PRIMARY KEY,
    -- Compte actuellement connecté sur cet appareil (claim « sub »).
    keycloak_user_id VARCHAR(36)  NOT NULL,
    -- Jeton d'enregistrement FCM. ~163 caractères aujourd'hui, mais Google ne
    -- garantit aucune longueur maximale : on prend large.
    token            VARCHAR(512) NOT NULL,
    plateforme       VARCHAR(10)  NOT NULL,
    -- Laquelle des deux applications : un même téléphone peut porter les deux.
    application      VARCHAR(15)  NOT NULL,
    actif            BOOLEAN      NOT NULL DEFAULT TRUE,
    -- Dernier signe de vie de l'appareil (enregistrement ou rafraîchissement du
    -- jeton). Permet de purger le parc dormant sans attendre un rejet de FCM.
    vu_le            TIMESTAMP,
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    -- Le jeton identifie un APPAREIL, pas un utilisateur : unicité globale.
    -- Quand un second compte se connecte sur le même téléphone, FCM rend le
    -- même jeton et la ligne doit changer de propriétaire, pas se dupliquer —
    -- sans quoi l'ancien utilisateur continuerait de recevoir ses notifications
    -- sur un appareil qui ne lui appartient plus.
    CONSTRAINT uk_device_tokens_token      UNIQUE (token),
    CONSTRAINT chk_device_tokens_plateforme  CHECK (plateforme  IN ('ANDROID', 'IOS')),
    CONSTRAINT chk_device_tokens_application CHECK (application IN ('MANAGER', 'CHAUFFEUR'))
);

-- Lecture dominante : « tous les appareils actifs de cet utilisateur », juste
-- avant chaque envoi.
CREATE INDEX IF NOT EXISTS idx_device_tokens_destinataire
    ON device_tokens(keycloak_user_id)
    WHERE actif = TRUE;

CREATE TABLE IF NOT EXISTS notifications (
    id                       BIGSERIAL    PRIMARY KEY,
    destinataire_keycloak_id VARCHAR(36)  NOT NULL,
    type                     VARCHAR(40)  NOT NULL,
    titre                    VARCHAR(120) NOT NULL,
    corps                    VARCHAR(300) NOT NULL,
    -- Cible du lien profond, désignée par son type et son identifiant métier
    -- (ex. LIGNE_PENALITE / 4213). Volontairement sans clé étrangère : la trace
    -- de la notification doit survivre à la suppression de l'objet notifié.
    entite_type              VARCHAR(40),
    entite_id                BIGINT,
    lue                      BOOLEAN      NOT NULL DEFAULT FALSE,
    lue_le                   TIMESTAMP,
    -- Horodatage de la remise à FCM. Nul = notification créée mais jamais
    -- poussée (aucun appareil enregistré, ou envoi désactivé).
    envoyee_le               TIMESTAMP,
    created_at               TIMESTAMP,
    updated_at               TIMESTAMP
);

-- Le flux du centre de notifications : les plus récentes d'abord.
CREATE INDEX IF NOT EXISTS idx_notifications_destinataire
    ON notifications(destinataire_keycloak_id, created_at DESC);

-- Le badge de non-lus est relu à chaque ouverture de l'application : il mérite
-- son index partiel, qui reste petit puisque les notifications finissent lues.
CREATE INDEX IF NOT EXISTS idx_notifications_non_lues
    ON notifications(destinataire_keycloak_id)
    WHERE lue = FALSE;
