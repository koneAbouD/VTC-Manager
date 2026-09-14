package com.tmk.vtcmanager.application.domain.arrete;

/**
 * Chauffeur que concerne un arrêté, avec de quoi le joindre : bénéficiaire d'un
 * règlement, ou débiteur d'une créance que l'arrêté éteint.
 *
 * <p>Le second n'a pas toujours de règlement : sur un arrêté par véhicule, un
 * chauffeur sans dépôt dont un collègue solde la dette n'apparaît que dans les
 * lignes. C'est pourtant à lui aussi que le décompte doit parvenir.</p>
 *
 * <p>Réservé au gestionnaire : le téléphone d'un chauffeur ne doit jamais
 * parvenir à ses collègues par l'application chauffeur.</p>
 */
public record ChauffeurArrete(Long id, String nom, String telephone) {
}
