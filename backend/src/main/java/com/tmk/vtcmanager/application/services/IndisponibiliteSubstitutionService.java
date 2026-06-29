package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

/// Résout, à une date donnée, le remplacement d'un chauffeur titulaire par son
/// remplaçant lorsqu'une indisponibilité couvre cette date.
///
/// Modèle "overlay" : on ne modifie jamais les assignations du programme ; le
/// remplacement est calculé à la lecture/génération, uniquement pour les jours
/// effectivement couverts par l'indisponibilité.
@RequiredArgsConstructor
public class IndisponibiliteSubstitutionService {

    private final IndisponibiliteRepository indisponibiliteRepository;

    /** Indique si [chauffeurId] est indisponible à [date]. */
    public boolean estIndisponible(Long chauffeurId, LocalDate date) {
        if (chauffeurId == null) return false;
        return indisponibiliteRepository.findByChauffeurId(chauffeurId).stream()
                .anyMatch(i -> couvre(i, date));
    }

    /** Map titulaireId → remplaçantId pour toutes les indisponibilités couvrant [date]. */
    public Map<Long, Long> substitutionsForDate(LocalDate date) {
        Map<Long, Long> map = new HashMap<>();
        for (Indisponibilite i : indisponibiliteRepository.findAll()) {
            if (!couvre(i, date)) continue;
            Long titulaire = i.getChauffeur() != null ? i.getChauffeur().getId() : null;
            Long remplacant = i.getChauffeurRemplacant() != null
                    ? i.getChauffeurRemplacant().getId() : null;
            if (titulaire != null && remplacant != null && !titulaire.equals(remplacant)) {
                map.put(titulaire, remplacant);
            }
        }
        return map;
    }

    /**
     * Applique les substitutions de [date] à une liste de chauffeurs planifiés :
     * tout titulaire indisponible est remplacé par son remplaçant. Les doublons
     * sont évités (ordre préservé).
     */
    public List<Long> appliquer(List<Long> chauffeursPlanifies, LocalDate date) {
        Map<Long, Long> subs = substitutionsForDate(date);
        if (subs.isEmpty()) return chauffeursPlanifies;
        LinkedHashSet<Long> effectifs = new LinkedHashSet<>();
        for (Long id : chauffeursPlanifies) {
            effectifs.add(subs.getOrDefault(id, id));
        }
        return new ArrayList<>(effectifs);
    }

    /** Vrai si l'indisponibilité couvre la date (une indispo annulée n'a aucun effet). */
    private boolean couvre(Indisponibilite i, LocalDate date) {
        if (i.getStatut() == IndisponibiliteStatut.ANNULEE) return false;
        if (i.getDateDebut() == null) return false;
        if (date.isBefore(i.getDateDebut())) return false;
        if (i.getDateFin() != null && date.isAfter(i.getDateFin())) return false;
        return true;
    }
}
