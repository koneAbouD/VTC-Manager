package com.tmk.vtcmanager.application.domain.reaffectation;

import java.util.List;

/**
 * Tout ce que l'écran de réaffectation a besoin de savoir, en un aller-retour :
 * qui peut reprendre la créance, et ce que le déplacement entraînera.
 *
 * <p>Une seule requête à l'ouverture de la feuille : deux appels séparés
 * feraient apparaître la liste puis, un instant plus tard, les conséquences —
 * et le second échouerait parfois seul, laissant un écran à moitié su.
 */
public record ApercuReaffectation(List<CandidatReaffectation> candidats,
                                  ImpactsReaffectation impacts) {}
