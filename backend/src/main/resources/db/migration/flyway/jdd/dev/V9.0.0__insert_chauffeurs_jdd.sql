-- JDD Chauffeurs - Environnement DEV

INSERT INTO chauffeurs (nom, prenom, genre, type, date_naissance, telephone, email, adresse, statut, date_embauche, created_at, updated_at)
VALUES
    ('DIALLO',  'Mamadou', 'HOMME', 'PRINCIPAL',   '1988-04-12', '+33 6 12 34 56 78', 'mamadou.diallo@vtcmanager.dev',  '12 Rue de la Paix, 75001 Paris',           'ACTIF',    '2021-06-01', NOW(), NOW()),
    ('KONÉ',    'Ibrahim', 'HOMME', 'PRINCIPAL',   '1991-09-30', '+33 6 23 45 67 89', 'ibrahim.kone@vtcmanager.dev',    '8 Avenue des Champs, 75008 Paris',         'ACTIF',    '2022-01-15', NOW(), NOW()),
    ('MARTIN',  'Julien',  'HOMME', 'PRINCIPAL',   '1985-02-20', '+33 6 34 56 78 90', 'julien.martin@vtcmanager.dev',   '25 Rue du Commerce, 92100 Boulogne',       'ACTIF',    '2020-09-10', NOW(), NOW()),
    ('BENALI',  'Rachid',  'HOMME', 'PRINCIPAL',   '1993-07-05', '+33 6 45 67 89 01', 'rachid.benali@vtcmanager.dev',   '3 Bd Victor Hugo, 93100 Montreuil',        'ACTIF',    '2022-11-01', NOW(), NOW()),
    ('NGUYEN',  'Thanh',   'HOMME', 'INTERIMAIRE', '1982-11-18', '+33 6 56 78 90 12', 'thanh.nguyen@vtcmanager.dev',    '47 Rue de la République, 94200 Ivry',      'INACTIF',  '2019-04-20', NOW(), NOW()),
    ('DUPONT',  'Thomas',  'HOMME', 'PRINCIPAL',   '1995-03-25', '+33 6 67 89 01 23', 'thomas.dupont@vtcmanager.dev',   '15 Allée des Roses, 91000 Évry',           'ACTIF',    '2023-03-05', NOW(), NOW()),
    ('TRAORE',  'Seydou',  'HOMME', 'INTERIMAIRE', '1989-06-14', '+33 6 78 90 12 34', 'seydou.traore@vtcmanager.dev',   '9 Rue Gambetta, 92300 Levallois',          'SUSPENDU', '2021-07-18', NOW(), NOW()),
    ('GARCIA',  'Carlos',  'HOMME', 'PRINCIPAL',   '1987-01-08', '+33 6 89 01 23 45', 'carlos.garcia@vtcmanager.dev',   '31 Rue de Rivoli, 75004 Paris',            'ACTIF',    '2021-02-28', NOW(), NOW());