package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Marque;
import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.MarqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Gestion (administration) du référentiel « Marque » : liste, création, mise à
 * jour, activation/désactivation et suppression. L'unicité (nom, type) est
 * garantie par la contrainte de base {@code uk_marques_nom_type} (→ 409 via le
 * gestionnaire d'exceptions global).
 */
@Service
@RequiredArgsConstructor
public class MarqueReferentielUseCase {

    private static final String ENTITE = "Marque";
    private static final String ENTITE_TYPE = "Type de véhicule";

    private final MarqueRepository marqueRepository;
    private final TypeVehiculeRepository typeVehiculeRepository;

    public List<Marque> lister() {
        return marqueRepository.findAll();
    }

    public Marque creer(String nom, Long typeId, String paysOrigine) {
        TypeVehicule type = chargerType(typeId);
        return marqueRepository.save(Marque.create(nom, type, paysOrigine));
    }

    public Marque mettreAJour(Long id, String nom, Long typeId, String paysOrigine) {
        Marque existant = charger(id);
        TypeVehicule type = chargerType(typeId);
        existant.update(nom, type, paysOrigine);
        return marqueRepository.save(existant);
    }

    public Marque changerActivation(Long id, boolean actif) {
        Marque existant = charger(id);
        existant.changerActivation(actif);
        return marqueRepository.save(existant);
    }

    public void supprimer(Long id) {
        if (!marqueRepository.existsById(id)) {
            throw ResourceNotFoundException.of(ENTITE, id);
        }
        marqueRepository.deleteById(id);
    }

    private Marque charger(Long id) {
        return marqueRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of(ENTITE, id));
    }

    private TypeVehicule chargerType(Long typeId) {
        return typeVehiculeRepository.findById(typeId)
                .orElseThrow(() -> ResourceNotFoundException.of(ENTITE_TYPE, typeId));
    }
}
