package com.tmk.vtcmanager.application.usecases.fournisseur;

import com.tmk.vtcmanager.application.domain.fournisseur.Fournisseur;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.FournisseurRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/** Référentiel des fournisseurs : création, modification, désactivation. */
@RequiredArgsConstructor
public class GestionFournisseurUseCase {

    private final FournisseurRepository fournisseurRepository;

    @Transactional(readOnly = true)
    public List<Fournisseur> lister(boolean actifsSeulement) {
        return fournisseurRepository.findAll(actifsSeulement);
    }

    @Transactional(readOnly = true)
    public Fournisseur parId(Long id) {
        return fournisseurRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Fournisseur", id));
    }

    @Transactional
    public Fournisseur creer(Fournisseur fournisseur) {
        if (fournisseurRepository.existsByNom(fournisseur.getNom())) {
            throw new ResourceAlreadyExistsException(
                    "Un fournisseur porte déjà le nom « " + fournisseur.getNom() + " ».");
        }
        fournisseur.setId(null);
        fournisseur.setActif(true);
        return fournisseurRepository.save(fournisseur);
    }

    @Transactional
    public Fournisseur modifier(Long id, Fournisseur data) {
        Fournisseur existant = parId(id);
        // Le nom reste unique, mais un fournisseur peut garder le sien.
        if (!existant.getNom().equalsIgnoreCase(data.getNom())
                && fournisseurRepository.existsByNom(data.getNom())) {
            throw new ResourceAlreadyExistsException(
                    "Un fournisseur porte déjà le nom « " + data.getNom() + " ».");
        }
        existant.setNom(data.getNom());
        existant.setType(data.getType());
        existant.setTelephone(data.getTelephone());
        existant.setEmail(data.getEmail());
        existant.setAdresse(data.getAdresse());
        existant.setNumeroCompteContribuable(data.getNumeroCompteContribuable());
        existant.setCommentaire(data.getCommentaire());
        return fournisseurRepository.save(existant);
    }

    /**
     * Désactive un fournisseur : il disparaît des listes de saisie sans que ses
     * factures passées ne bougent — on ne supprime pas un tiers qui a un
     * historique comptable.
     */
    @Transactional
    public Fournisseur changerActivation(Long id, boolean actif) {
        Fournisseur existant = parId(id);
        existant.setActif(actif);
        return fournisseurRepository.save(existant);
    }
}
