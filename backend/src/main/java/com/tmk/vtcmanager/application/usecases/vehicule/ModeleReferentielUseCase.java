package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Marque;
import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.MarqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Gestion (administration) du référentiel « Modèle » : liste, création, mise à
 * jour, activation/désactivation et suppression. Le type de véhicule est déduit
 * de la marque rattachée (un modèle appartient à une marque, elle-même typée).
 */
@Service
@RequiredArgsConstructor
public class ModeleReferentielUseCase {

    private static final String ENTITE = "Modèle";
    private static final String ENTITE_MARQUE = "Marque";

    private final ModeleRepository modeleRepository;
    private final MarqueRepository marqueRepository;

    public List<Modele> lister() {
        return modeleRepository.findAll();
    }

    public Modele creer(String nom, Long marqueId) {
        Marque marque = chargerMarque(marqueId);
        return modeleRepository.save(Modele.create(nom, marque.getType(), marque));
    }

    public Modele mettreAJour(Long id, String nom, Long marqueId) {
        Modele existant = charger(id);
        Marque marque = chargerMarque(marqueId);
        existant.update(nom, marque.getType(), marque);
        return modeleRepository.save(existant);
    }

    public Modele changerActivation(Long id, boolean actif) {
        Modele existant = charger(id);
        existant.changerActivation(actif);
        return modeleRepository.save(existant);
    }

    public void supprimer(Long id) {
        if (!modeleRepository.existsById(id)) {
            throw ResourceNotFoundException.of(ENTITE, id);
        }
        modeleRepository.deleteById(id);
    }

    private Modele charger(Long id) {
        return modeleRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of(ENTITE, id));
    }

    private Marque chargerMarque(Long marqueId) {
        return marqueRepository.findById(marqueId)
                .orElseThrow(() -> ResourceNotFoundException.of(ENTITE_MARQUE, marqueId));
    }
}
