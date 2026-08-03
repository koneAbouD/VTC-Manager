-- Détail d'une notification, lisible seulement dans l'application.
--
-- Le titre et le corps partent vers FCM et s'affichent sur l'écran verrouillé :
-- ils restent donc sobres, sans montant ni nom. Ce détail-ci ne quitte jamais
-- le serveur autrement que par l'API du centre de notifications, derrière le
-- jeton d'accès et le code de l'application — il peut donc nommer le chauffeur,
-- le véhicule et les sommes, ce qui rend l'information enfin exploitable pour
-- celui qui gère la caisse.
--
-- Nul pour les notifications qui n'ont rien à ajouter à leur corps.

ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS detail VARCHAR(300);
