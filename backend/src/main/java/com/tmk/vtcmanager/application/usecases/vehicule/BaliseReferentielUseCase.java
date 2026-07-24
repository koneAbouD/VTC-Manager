package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Balise;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.BaliseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Gestion (administration) du référentiel « Balise GPS » :
 * création, mise à jour, activation/désactivation et suppression.
 */
@Service
@RequiredArgsConstructor
public class BaliseReferentielUseCase {

    private static final String ENTITE = "Balise";

    private final BaliseRepository repository;

    public Balise creer(String identifiant, String numeroTelephone) {
        if (repository.existsByIdentifiant(identifiant)) {
            throw ResourceAlreadyExistsException.of(ENTITE, "identifiant", identifiant);
        }
        return repository.save(Balise.create(identifiant, numeroTelephone));
    }

    public Balise mettreAJour(Long id, String identifiant, String numeroTelephone) {
        Balise existant = charger(id);
        repository.findByIdentifiant(identifiant)
                .filter(autre -> !autre.getId().equals(id))
                .ifPresent(autre -> {
                    throw ResourceAlreadyExistsException.of(ENTITE, "identifiant", identifiant);
                });
        existant.update(identifiant, numeroTelephone);
        return repository.save(existant);
    }

    public Balise changerActivation(Long id, boolean actif) {
        Balise existant = charger(id);
        existant.changerActivation(actif);
        return repository.save(existant);
    }

    public void supprimer(Long id) {
        if (!repository.existsById(id)) {
            throw ResourceNotFoundException.of(ENTITE, id);
        }
        repository.deleteById(id);
    }

    private Balise charger(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of(ENTITE, id));
    }
}
