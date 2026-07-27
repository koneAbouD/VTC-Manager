-- Provision sur créances dans la photo de clôture.
--
-- Le bilan courant retient les créances NETTES de dépréciation ; l'archive, elle,
-- ne stockait que les brutes et calculait son total d'actif dessus. Les deux
-- lectures d'un même bilan ne coïncidaient donc pas. On archive désormais la
-- provision et le net, et le total d'actif suit le net — comme à l'écran.
ALTER TABLE etats_cloture_periode
    ADD COLUMN IF NOT EXISTS provision_creances NUMERIC(19, 2) NOT NULL DEFAULT 0;
ALTER TABLE etats_cloture_periode
    ADD COLUMN IF NOT EXISTS creances_nettes    NUMERIC(19, 2) NOT NULL DEFAULT 0;

-- Reprise : aucune clôture n'a encore été archivée avec provision, le net vaut
-- donc le brut pour les lignes existantes.
UPDATE etats_cloture_periode
   SET creances_nettes = creances_chauffeurs
 WHERE creances_nettes = 0;
