-- Date de prise d'effet de la suspension d'un chauffeur. Renseignée lorsque le
-- statut passe à SUSPENDU, remise à NULL à la levée. Sert à expliciter "suspendu
-- depuis le ..." dans les messages et l'UI.
ALTER TABLE chauffeurs ADD COLUMN date_suspension DATE;
