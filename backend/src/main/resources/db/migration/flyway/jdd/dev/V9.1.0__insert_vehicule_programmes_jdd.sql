-- ─────────────────────────────────────────────────────────────────────────────
-- PROGRAMMES SOLO — chauffeur assigné
-- ─────────────────────────────────────────────────────────────────────────────

-- AA-760-QL-01 : Mercedes E · Premium VTC · 08h–20h · DIALLO Mamadou
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'AA-760-QL-01'),
    1, 'JOURNALIER', '08:00:00', '20:00:00',
    'MANUELLE', NULL, NULL,
    FALSE, NULL,
    NOW(), NOW()
);

INSERT INTO vehicule_programme_chauffeurs (programme_id, chauffeur_id, ordre_alternance, date_service, created_at, updated_at)
VALUES (
    (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'AA-760-QL-01'),
    (SELECT id FROM chauffeurs WHERE nom = 'DIALLO' AND prenom = 'Mamadou'),
    1, '2026-05-31', NOW(), NOW()
);

-- AA-991-SJ-01 : BMW Série 5 · Premium VTC · 08h–20h · KONÉ Ibrahim
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'AA-991-SJ-01'),
    1, 'JOURNALIER', '08:00:00', '20:00:00',
    'MANUELLE', NULL, NULL,
    FALSE, NULL,
    NOW(), NOW()
);

INSERT INTO vehicule_programme_chauffeurs (programme_id, chauffeur_id, ordre_alternance, date_service, created_at, updated_at)
VALUES (
    (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'AA-991-SJ-01'),
    (SELECT id FROM chauffeurs WHERE nom = 'KONÉ' AND prenom = 'Ibrahim'),
    1, '2026-05-31', NOW(), NOW()
);

-- AA-247-YC-01 : Peugeot 508 · Premium VTC · 06h–22h · GARCIA Carlos · Salaire vendredi
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'AA-247-YC-01'),
    1, 'JOURNALIER', '06:00:00', '22:00:00',
    'MANUELLE', NULL, NULL,
    TRUE, 'VENDREDI',
    NOW(), NOW()
);

INSERT INTO vehicule_programme_chauffeurs (programme_id, chauffeur_id, ordre_alternance, date_service, created_at, updated_at)
VALUES (
    (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'AA-247-YC-01'),
    (SELECT id FROM chauffeurs WHERE nom = 'GARCIA' AND prenom = 'Carlos'),
    1, '2026-05-31', NOW(), NOW()
);

-- AB-929-FE-01 : Suzuki S-Presso · Premium VTC · 06h–22h · DUPONT Thomas
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'AB-929-FE-01'),
    1, 'JOURNALIER', '06:00:00', '22:00:00',
    'MANUELLE', NULL, NULL,
    FALSE, NULL,
    NOW(), NOW()
);

INSERT INTO vehicule_programme_chauffeurs (programme_id, chauffeur_id, ordre_alternance, date_service, created_at, updated_at)
VALUES (
    (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'AB-929-FE-01'),
    (SELECT id FROM chauffeurs WHERE nom = 'DUPONT' AND prenom = 'Thomas'),
    1, '2026-05-31', NOW(), NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- PROGRAMMES ALTERNANCE AUTOMATIQUE
-- ─────────────────────────────────────────────────────────────────────────────

-- AA-837-TP-01 : Audi A6 · Standard TAXI · 06h–22h · 2 chauffeurs · Rotation 7j
--   Chauffeur 1 : MARTIN Julien  (commence en service)
--   Chauffeur 2 : BENALI Rachid  (attend sa rotation)
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'AA-837-TP-01'),
    2, 'JOURNALIER', '06:00:00', '22:00:00',
    'AUTOMATIQUE', 7, '2026-01-01',
    FALSE, NULL,
    NOW(), NOW()
);

INSERT INTO vehicule_programme_chauffeurs (programme_id, chauffeur_id, ordre_alternance, date_service, created_at, updated_at)
VALUES
    (
        (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'AA-837-TP-01'),
        (SELECT id FROM chauffeurs WHERE nom = 'MARTIN' AND prenom = 'Julien'),
        1, '2026-05-28', NOW(), NOW()
    ),
    (
        (SELECT vp.id FROM vehicule_programmes vp JOIN vehicules v ON vp.vehicule_id = v.id WHERE v.immatriculation = 'AA-837-TP-01'),
        (SELECT id FROM chauffeurs WHERE nom = 'BENALI' AND prenom = 'Rachid'),
        2, '2026-06-04', NOW(), NOW()
    );

-- AA-314-TH-01 : Toyota Camry · Standard TAXI · 05h–23h · 2 chauffeurs · Rotation 7j
--   Pas encore de chauffeurs assignés (en attente de recrutement)
INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES (
    (SELECT id FROM vehicules WHERE immatriculation = 'AA-314-TH-01'),
    2, 'JOURNALIER', '05:00:00', '23:00:00',
    'AUTOMATIQUE', 7, '2026-06-01',
    FALSE, NULL,
    NOW(), NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- PROGRAMMES SOLO — sans chauffeur assigné (véhicules récents / disponibles)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO vehicule_programmes (
    vehicule_id, nombre_chauffeurs_autorises, type_programme,
    heure_debut_service, heure_fin_service,
    mode_alternance, jours_alternance, date_debut_alternance,
    jour_salaire_actif, jour_salaire,
    created_at, updated_at
) VALUES
    -- AB-688-AX : Dacia Logan · Standard TAXI · 06h–22h
    (
        (SELECT id FROM vehicules WHERE immatriculation = 'AB-688-AX'),
        1, 'JOURNALIER', '06:00:00', '22:00:00',
        'MANUELLE', NULL, NULL, FALSE, NULL, NOW(), NOW()
    ),
    -- AA-728-ZT-01 : Kia Rio · Standard VTC · 06h–22h
    (
        (SELECT id FROM vehicules WHERE immatriculation = 'AA-728-ZT-01'),
        1, 'JOURNALIER', '06:00:00', '22:00:00',
        'MANUELLE', NULL, NULL, FALSE, NULL, NOW(), NOW()
    ),
    -- AB-192-EJ-01 : Suzuki S-Presso · Standard · 08h–20h (en maintenance)
    (
        (SELECT id FROM vehicules WHERE immatriculation = 'AB-192-EJ-01'),
        1, 'JOURNALIER', '08:00:00', '20:00:00',
        'MANUELLE', NULL, NULL, FALSE, NULL, NOW(), NOW()
    ),
    -- AB-187-EJ-01 : Suzuki S-Presso · Standard · 06h–22h (en maintenance)
    (
        (SELECT id FROM vehicules WHERE immatriculation = 'AB-187-EJ-01'),
        1, 'JOURNALIER', '06:00:00', '22:00:00',
        'MANUELLE', NULL, NULL, FALSE, NULL, NOW(), NOW()
    );
