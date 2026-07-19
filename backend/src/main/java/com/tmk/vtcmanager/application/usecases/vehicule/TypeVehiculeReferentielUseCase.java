package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.TypeVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Gestion (administration) du référentiel « Type de véhicule » :
 * création, mise à jour, activation/désactivation et suppression.
 * Regroupe le cycle de vie d'un même référentiel (responsabilité unique) tout
 * en évitant la duplication d'une classe par opération.
 */
@Service
@RequiredArgsConstructor
public class TypeVehiculeReferentielUseCase {

    private static final String ENTITE = "Type de véhicule";

    private final TypeVehiculeRepository repository;

    public TypeVehicule creer(String nom, String description) {
        if (repository.existsByNom(nom)) {
            throw ResourceAlreadyExistsException.of(ENTITE, "nom", nom);
        }
        return repository.save(TypeVehicule.create(nom, description));
    }

    public TypeVehicule mettreAJour(Long id, String nom, String description) {
        TypeVehicule existant = charger(id);
        repository.findByNom(nom)
                .filter(autre -> !autre.getId().equals(id))
                .ifPresent(autre -> {
                    throw ResourceAlreadyExistsException.of(ENTITE, "nom", nom);
                });
        existant.update(nom, description);
        return repository.save(existant);
    }

    public TypeVehicule changerActivation(Long id, boolean actif) {
        TypeVehicule existant = charger(id);
        existant.changerActivation(actif);
        return repository.save(existant);
    }

    public void supprimer(Long id) {
        if (!repository.existsById(id)) {
            throw ResourceNotFoundException.of(ENTITE, id);
        }
        repository.deleteById(id);
    }

    private TypeVehicule charger(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of(ENTITE, id));
    }
}
