-- Regroupement des notifications d'un même geste.
--
-- Un encaissement rapide solde la recette et la cotisation en deux requêtes
-- successives : sans clé de regroupement, le chauffeur reçoit deux messages à
-- une seconde d'intervalle pour un seul versement, et son centre en garde deux
-- lignes. La clé identifie le geste (par exemple ENCAISSEMENT:9:2026-08-03,
-- soit « versements du chauffeur 9 reçus le 3 août ») : la deuxième
-- notification réécrit la première au lieu de s'ajouter à elle.
--
-- Nulle par défaut : une notification sans clé ne se regroupe avec rien, ce qui
-- reste le cas de toutes celles qui portent un fait unique.

ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS cle_groupe VARCHAR(60);

-- Lecture unique : « existe-t-il déjà, pour ce destinataire, une notification
-- non lue portant cette clé ? », posée juste avant chaque création. L'index
-- partiel reste petit — une notification finit toujours par être lue, et sort
-- alors de l'index.
CREATE INDEX IF NOT EXISTS idx_notifications_cle_groupe
    ON notifications(destinataire_keycloak_id, cle_groupe)
    WHERE lue = FALSE AND cle_groupe IS NOT NULL;
