-- Jeton de version des fiches véhicule et chauffeur.
--
-- Les applications renvoient la version de la fiche qu'elles ont affichée ;
-- si elle a changé entre-temps (autre gestionnaire, statut recalculé, fiche
-- ouverte depuis le cache hors connexion), la modification est refusée au lieu
-- d'écraser silencieusement l'autre.
--
-- La version est tenue par la base et non par l'application : le trigger
-- l'incrémente à chaque UPDATE, y compris les mises à jour en masse qui
-- contournent l'ORM. L'application la relit, ne l'écrit jamais.
ALTER TABLE vehicules ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE chauffeurs ADD COLUMN version BIGINT NOT NULL DEFAULT 0;

CREATE FUNCTION incrementer_version() RETURNS trigger AS $$
BEGIN
    NEW.version := OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_vehicules_version
    BEFORE UPDATE ON vehicules
    FOR EACH ROW EXECUTE FUNCTION incrementer_version();

CREATE TRIGGER trg_chauffeurs_version
    BEFORE UPDATE ON chauffeurs
    FOR EACH ROW EXECUTE FUNCTION incrementer_version();
