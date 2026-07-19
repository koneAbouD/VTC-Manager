package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Gestion (administration) du référentiel « Type d'activité » :
 * création, mise à jour, activation/désactivation et suppression.
 */
@Service
@RequiredArgsConstructor
public class TypeActiviteReferentielUseCase {

    private static final String ENTITE = "Type d'activité";

    private final TypeActiviteRepository repository;

    public TypeActivite creer(String nom, String description) {
        if (repository.existsByNom(nom)) {
            throw ResourceAlreadyExistsException.of(ENTITE, "nom", nom);
        }
        return repository.save(TypeActivite.create(nom, description));
    }

    public TypeActivite mettreAJour(Long id, String nom, String description) {
        TypeActivite existant = charger(id);
        repository.findByNom(nom)
                .filter(autre -> !autre.getId().equals(id))
                .ifPresent(autre -> {
                    throw ResourceAlreadyExistsException.of(ENTITE, "nom", nom);
                });
        existant.update(nom, description);
        return repository.save(existant);
    }

    public TypeActivite changerActivation(Long id, boolean actif) {
        TypeActivite existant = charger(id);
        existant.changerActivation(actif);
        return repository.save(existant);
    }

    public void supprimer(Long id) {
        if (!repository.existsById(id)) {
            throw ResourceNotFoundException.of(ENTITE, id);
        }
        repository.deleteById(id);
    }

    private TypeActivite charger(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of(ENTITE, id));
    }
}
