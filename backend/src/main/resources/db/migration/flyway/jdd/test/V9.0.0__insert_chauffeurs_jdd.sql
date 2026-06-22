-- JDD Chauffeurs - Environnement TEST

INSERT INTO chauffeurs (nom, prenom, genre, type, date_naissance, telephone, email, adresse, statut, date_embauche, created_at, updated_at)
VALUES
    ('DIALLO', 'Mamadou', 'HOMME', 'PRINCIPAL',  '1988-04-12', '+33 6 12 34 56 78', 'mamadou.diallo@vtcmanager.test', '12 Rue de la Paix, 75001 Paris',      'ACTIF',   '2021-06-01', NOW(), NOW()),
    ('KONÉ',   'Ibrahim', 'HOMME', 'PRINCIPAL',  '1991-09-30', '+33 6 23 45 67 89', 'ibrahim.kone@vtcmanager.test',   '8 Avenue des Champs, 75008 Paris',    'ACTIF',   '2022-01-15', NOW(), NOW()),
    ('MARTIN', 'Julien',  'HOMME', 'PRINCIPAL',  '1985-02-20', '+33 6 34 56 78 90', 'julien.martin@vtcmanager.test',  '25 Rue du Commerce, 92100 Boulogne',  'ACTIF',   '2020-09-10', NOW(), NOW()),
    ('NGUYEN', 'Thanh',   'HOMME', 'INTERIMAIRE','1982-11-18', '+33 6 56 78 90 12', 'thanh.nguyen@vtcmanager.test',   '47 Rue de la République, 94200 Ivry', 'INACTIF', '2019-04-20', NOW(), NOW());