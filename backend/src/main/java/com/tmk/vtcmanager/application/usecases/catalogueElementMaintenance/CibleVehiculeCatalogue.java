package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.MarqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import lombok.RequiredArgsConstructor;

/**
 * Résout la marque et le modèle de véhicule auxquels un élément de catalogue
 * est réservé. Un modèle suffit à désigner sa marque : elle en est déduite, et
 * refusée si le client en a choisi une autre. Sans l'un ni l'autre, l'élément
 * reste générique.
 */
@RequiredArgsConstructor
public class CibleVehiculeCatalogue {

    private final MarqueRepository marqueRepository;
    private final ModeleRepository modeleRepository;

    public void appliquer(CatalogueElementMaintenance element, Long marqueId, Long modeleId) {
        if (modeleId != null) {
            Modele modele = modeleRepository.findById(modeleId)
                    .orElseThrow(() -> ResourceNotFoundException.of("Modèle", modeleId));
            Long marqueDuModele = modele.getMarque() != null ? modele.getMarque().getId() : null;
            if (marqueId != null && !marqueId.equals(marqueDuModele)) {
                throw new IllegalArgumentException(
                        "Le modèle « " + modele.getNom() + " » n'appartient pas à la marque choisie.");
            }
            element.affecterVehicule(marqueDuModele, modeleId);
            return;
        }
        if (marqueId != null && !marqueRepository.existsById(marqueId)) {
            throw ResourceNotFoundException.of("Marque", marqueId);
        }
        element.affecterVehicule(marqueId, null);
    }
}
