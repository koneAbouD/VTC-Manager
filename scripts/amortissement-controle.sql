BEGIN READ ONLY;
SELECT v.id, v.immatriculation imm, v.prix_achat prix, v.date_achat achat,
       v.date_mise_en_circulation mec, v.date_entree_flotte entree,
       v.duree_amortissement_mois duree_v, a.duree, a.depart,
       round(v.prix_achat * GREATEST(0, LEAST(p.fin_exclue-1, date_trunc('month',current_date)::date + interval '1 month - 1 day')::date
             - GREATEST(a.depart, date_trunc('month',current_date)::date) + 1)::numeric / NULLIF(p.fin_exclue-a.depart,0)) dot_mois,
       round(v.prix_achat * GREATEST(0, LEAST(p.fin_exclue-1, current_date) - a.depart + 1)::numeric / NULLIF(p.fin_exclue-a.depart,0)) cumul,
       round(GREATEST(0, v.prix_achat - v.prix_achat * GREATEST(0, LEAST(p.fin_exclue-1, current_date) - a.depart + 1)::numeric / NULLIF(p.fin_exclue-a.depart,0))) vnc
FROM vehicules v
CROSS JOIN LATERAL (SELECT COALESCE(v.duree_amortissement_mois,(SELECT NULLIF(pg.valeur,'')::int FROM parametres_generaux pg WHERE pg.cle='DUREE_AMORTISSEMENT_MOIS'),60) duree,
       COALESCE(v.date_entree_flotte, v.date_achat, v.date_mise_en_circulation) depart) a
CROSS JOIN LATERAL (SELECT (a.depart + (a.duree||' months')::interval)::date fin_exclue) p
ORDER BY a.depart NULLS FIRST;
SELECT cle, valeur FROM parametres_generaux WHERE cle ILIKE '%AMORT%';
ROLLBACK;
