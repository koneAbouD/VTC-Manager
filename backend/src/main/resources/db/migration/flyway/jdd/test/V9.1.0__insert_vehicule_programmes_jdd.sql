-- =============================================================================
-- V9.1.0__insert_vehicule_programmes_jdd.sql
-- Jeux de données programmes de travail — Environnement TEST
--
-- 3 programmes représentatifs :
--   AB-751-PR → DIALLO Mamadou    (solo, 1 chauffeur)
--   CD-753-PR → MARTIN + BENALI   (alternance automatique, 2 chauffeurs)
--   DE-754-ST → sans chauffeur    (alternance, non peuplé)
-- =============================================================================

-- AB-751-PR : solo · 08h–20h · DIALLO Mamadou
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'AB-751-PR'),
    1, 'JOURNALIER', '08:00:00', '20:00:00',
    'MANUELLE', NULL, NULL,
    FALSE, NULL,
    NOW(), NOW()
);

INSERT INTO vehicule_programme_chauffeurs (programme_id, chauffeur_id, ordre_alternance, date_service, created_at, updated_at)
VALUES (
    (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'AB-751-PR'),
    (SELECT id FROM chauffeurs WHERE nom = 'DIALLO' AND prenom = 'Mamadou'),
    1, '2026-05-31', NOW(), NOW()
);

-- CD-753-PR : alternance auto 7j · 06h–22h · MARTIN + BENALI
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'CD-753-PR'),
    2, 'JOURNALIER', '06:00:00', '22:00:00',
    'AUTOMATIQUE', 7, '2026-01-01',
    FALSE, NULL,
    NOW(), NOW()
);

INSERT INTO vehicule_programme_chauffeurs (programme_id, chauffeur_id, ordre_alternance, date_service, created_at, updated_at)
VALUES
    (
        (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'CD-753-PR'),
        (SELECT id FROM chauffeurs WHERE nom = 'MARTIN' AND prenom = 'Julien'),
        1, '2026-05-28', NOW(), NOW()
    ),
    (
        (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'CD-753-PR'),
        (SELECT id FROM chauffeurs WHERE nom = 'BENALI' AND prenom = 'Rachid'),
        2, '2026-06-04', NOW(), NOW()
    );

-- DE-754-ST : alternance auto 7j · 05h–23h · sans chauffeur
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'DE-754-ST'),
    2, 'JOURNALIER', '05:00:00', '23:00:00',
    'AUTOMATIQUE', 7, '2026-06-01',
    FALSE, NULL,
    NOW(), NOW()
);
