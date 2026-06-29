-- Statut "manuel" verrouillant du chauffeur : INACTIF (fin/mise en sommeil de
-- collaboration) ou SUSPENDU (décision disciplinaire). Lorsqu'il est renseigné,
-- il a priorité sur le statut calculé automatiquement (EN_CONGE via indisponibilité).
ALTER TABLE chauffeurs ADD COLUMN statut_manuel VARCHAR(30);
