package com.tmk.vtcmanager.application.usecases.partenaire;

import com.tmk.vtcmanager.application.domain.partenaire.TypePartenaire;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.TypePartenaireRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Référentiel « Type de partenaire » : les familles de tiers (prestataire,
 * fournisseur, administration, bailleur, assurance…), paramétrables sans
 * redéploiement.
 */
@RequiredArgsConstructor
public class TypePartenaireReferentielUseCase {

    private static final String ENTITE = "Type de partenaire";

    private final TypePartenaireRepository repository;

    @Transactional(readOnly = true)
    public List<TypePartenaire> lister(boolean actifsSeulement) {
        return actifsSeulement ? repository.findAllActifs() : repository.findAll();
    }

    @Transactional(readOnly = true)
    public TypePartenaire parId(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of(ENTITE, id));
    }

    @Transactional
    public TypePartenaire creer(String nom, String description) {
        if (repository.existsByNom(nom)) {
            throw ResourceAlreadyExistsException.of(ENTITE, "nom", nom);
        }
        return repository.save(TypePartenaire.create(nom, description));
    }

    @Transactional
    public TypePartenaire mettreAJour(Long id, String nom, String description) {
        TypePartenaire existant = parId(id);
        repository.findByNom(nom)
                .filter(autre -> !autre.getId().equals(id))
                .ifPresent(autre -> {
                    throw ResourceAlreadyExistsException.of(ENTITE, "nom", nom);
                });
        existant.update(nom, description);
        return repository.save(existant);
    }

    @Transactional
    public TypePartenaire changerActivation(Long id, boolean actif) {
        TypePartenaire existant = parId(id);
        existant.changerActivation(actif);
        return repository.save(existant);
    }

    /**
     * Supprime un type inutilisé. Dès qu'un partenaire le porte, la suppression
     * est refusée : la famille reste lisible sur l'historique. La désactivation
     * est alors la bonne voie — elle retire le type des saisies à venir.
     */
    @Transactional
    public void supprimer(Long id) {
        if (!repository.existsById(id)) {
            throw ResourceNotFoundException.of(ENTITE, id);
        }
        if (repository.estUtilise(id)) {
            throw new IllegalStateException(
                    "Ce type est porté par au moins un partenaire : désactivez-le plutôt.");
        }
        repository.deleteById(id);
    }
}
