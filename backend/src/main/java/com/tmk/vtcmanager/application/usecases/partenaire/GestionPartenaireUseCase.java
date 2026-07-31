package com.tmk.vtcmanager.application.usecases.partenaire;

import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.partenaire.TypePartenaire;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.PartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypePartenaireRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/** Répertoire des partenaires : création, modification, désactivation. */
@RequiredArgsConstructor
public class GestionPartenaireUseCase {

    private final PartenaireRepository partenaireRepository;
    private final TypePartenaireRepository typePartenaireRepository;

    @Transactional(readOnly = true)
    public List<Partenaire> lister(boolean actifsSeulement) {
        return partenaireRepository.findAll(actifsSeulement);
    }

    @Transactional(readOnly = true)
    public Partenaire parId(Long id) {
        return partenaireRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Partenaire", id));
    }

    @Transactional
    public Partenaire creer(Partenaire partenaire) {
        if (partenaireRepository.existsByNom(partenaire.getNom())) {
            throw new ResourceAlreadyExistsException(
                    "Un partenaire porte déjà le nom « " + partenaire.getNom() + " ».");
        }
        partenaire.setId(null);
        partenaire.setActif(true);
        partenaire.setType(resoudreType(partenaire.getType()));
        return partenaireRepository.save(partenaire);
    }

    @Transactional
    public Partenaire modifier(Long id, Partenaire data) {
        Partenaire existant = parId(id);
        // Le nom reste unique, mais un partenaire peut garder le sien.
        if (!existant.getNom().equalsIgnoreCase(data.getNom())
                && partenaireRepository.existsByNom(data.getNom())) {
            throw new ResourceAlreadyExistsException(
                    "Un partenaire porte déjà le nom « " + data.getNom() + " ».");
        }
        existant.setNom(data.getNom());
        existant.setType(resoudreType(data.getType()));
        existant.setTelephone(data.getTelephone());
        existant.setEmail(data.getEmail());
        existant.setAdresse(data.getAdresse());
        existant.setNumeroCompteContribuable(data.getNumeroCompteContribuable());
        existant.setCommentaire(data.getCommentaire());
        return partenaireRepository.save(existant);
    }

    /**
     * Désactive un partenaire : il disparaît des listes de saisie sans que ses
     * factures passées ne bougent — on ne supprime pas un tiers qui a un
     * historique comptable.
     */
    @Transactional
    public Partenaire changerActivation(Long id, boolean actif) {
        Partenaire existant = parId(id);
        existant.setActif(actif);
        return partenaireRepository.save(existant);
    }

    /**
     * La requête ne porte que l'identifiant du type : on le relit dans le
     * référentiel, ce qui vérifie du même coup qu'il existe.
     */
    private TypePartenaire resoudreType(TypePartenaire type) {
        Long typeId = type != null ? type.getId() : null;
        if (typeId == null) {
            throw new IllegalArgumentException("Le type du partenaire est obligatoire.");
        }
        return typePartenaireRepository.findById(typeId)
                .orElseThrow(() -> ResourceNotFoundException.of("Type de partenaire", typeId));
    }
}
