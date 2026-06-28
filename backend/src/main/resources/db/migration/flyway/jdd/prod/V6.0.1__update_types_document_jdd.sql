-- Mise à jour de la liste des types de documents (delta sur V6.0.0)
-- Ancien jeu remplacé par la nouvelle nomenclature.
-- Migration de rattrapage : la prod avait déjà appliqué l'ancien V6.0.0,
-- on applique ici uniquement la différence pour atteindre la liste cible.

-- 1) Suppression des types devenus obsolètes,
--    uniquement s'ils ne sont référencés par aucun document (FK documents.type_document_id).
DELETE FROM types_document td
WHERE td.nom IN (
    'Contrôle technique',
    'Vignette Crit''Air',
    'Autorisation de stationnement',
    'Carte professionnelle de transport',
    'Visite médicale',
    'Attestation de formation',
    'RIB'
)
AND NOT EXISTS (
    SELECT 1 FROM documents d WHERE d.type_document_id = td.id
);

-- 2) Insertion des nouveaux types (idempotent : nom est UNIQUE).
INSERT INTO types_document (nom, cible, obligatoire) VALUES
('Vignette', 'VEHICULE', true),
('Carte de stationnement', 'VEHICULE', false),
('Patente', 'VEHICULE', true)
ON CONFLICT (nom) DO NOTHING;
