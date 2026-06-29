-- Statut "manuel" verrouillant du véhicule : IMMOBILISE (panne/accident/saisie)
-- ou HORS_PARC (vendu/réformé/restitué). Lorsqu'il est renseigné, il a priorité
-- sur le statut calculé automatiquement (affectation / maintenance / immobilisation).
ALTER TABLE vehicules ADD COLUMN statut_manuel VARCHAR(30);
