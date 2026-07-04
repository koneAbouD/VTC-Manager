package com.tmk.vtcmanager.application.usecases.etatparc;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeStatutHistoriqueRepository;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcAlertesDto;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcSummaryResponse;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.VehiculeExceptionDto;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Photo du parc : compteurs par statut, taux calculés sur le parc actif
 * (HORS_PARC exclu du dénominateur), véhicules demandant une action et alertes
 * préventives. Lecture seule : agrège les données produites par les autres
 * modules sans aucune saisie propre.
 * <p>
 * Un véhicule DISPONIBLE est traité comme une anomalie douce : sans chauffeur
 * affecté, il ne produit pas de revenu.
 */
@RequiredArgsConstructor
public class GetEtatParcUseCase {

    private static final int SEUIL_ALERTE_DOCUMENTS_JOURS = 30;
    private static final int SEUIL_ALERTE_MAINTENANCE_JOURS = 7;

    private final VehiculeRepository vehiculeRepository;
    private final VehiculeStatutHistoriqueRepository statutHistoriqueRepository;
    private final DocumentRepository documentRepository;

    /**
     * @param groupeId   si non nul, restreint le parc aux véhicules de ce groupe
     * @param activiteId si non nul, restreint le parc aux véhicules de ce type d'activité
     */
    public EtatParcSummaryResponse execute(Long groupeId, Long activiteId) {
        LocalDate today = LocalDate.now();

        boolean filtreActif = groupeId != null || activiteId != null;

        List<Vehicule> vehicules = vehiculeRepository.findAll().stream()
                .filter(v -> matchGroupe(v, groupeId))
                .filter(v -> matchActivite(v, activiteId))
                .toList();

        Map<VehiculeStatus, Long> compteurs = new EnumMap<>(VehiculeStatus.class);
        for (Vehicule v : vehicules) {
            if (v.getStatut() != null) compteurs.merge(v.getStatut(), 1L, Long::sum);
        }
        int enService = compteurs.getOrDefault(VehiculeStatus.EN_SERVICE, 0L).intValue();
        int disponibles = compteurs.getOrDefault(VehiculeStatus.DISPONIBLE, 0L).intValue();
        int enMaintenance = compteurs.getOrDefault(VehiculeStatus.EN_MAINTENANCE, 0L).intValue();
        int immobilises = compteurs.getOrDefault(VehiculeStatus.IMMOBILISE, 0L).intValue();
        int horsParc = compteurs.getOrDefault(VehiculeStatus.HORS_PARC, 0L).intValue();

        int parcActif = vehicules.size() - horsParc;
        BigDecimal tauxDisponibilite = pourcentage(enService + disponibles, parcActif);
        BigDecimal tauxUtilisation = pourcentage(enService, parcActif);

        Map<Long, VehiculeStatutHistorique> periodesEnCours = statutHistoriqueRepository.findAllEnCours()
                .stream()
                .collect(Collectors.toMap(VehiculeStatutHistorique::getVehiculeId, Function.identity(),
                        (a, b) -> a));

        List<VehiculeExceptionDto> exceptions = vehicules.stream()
                .filter(v -> demandeUneAction(v.getStatut()))
                .map(v -> toException(v, periodesEnCours.get(v.getId())))
                .sorted(Comparator.comparing(VehiculeExceptionDto::joursDansStatut,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();

        return new EtatParcSummaryResponse(
                vehicules.size(), parcActif,
                enService, disponibles, enMaintenance, immobilises, horsParc,
                tauxDisponibilite, tauxUtilisation,
                exceptions,
                calculerAlertes(vehicules, today, filtreActif));
    }

    private boolean matchGroupe(Vehicule v, Long groupeId) {
        if (groupeId == null) return true;
        return v.getGroupe() != null && groupeId.equals(v.getGroupe().getId());
    }

    private boolean matchActivite(Vehicule v, Long activiteId) {
        if (activiteId == null) return true;
        return v.getActivite() != null && activiteId.equals(v.getActivite().getId());
    }

    /** IMMOBILISE, EN_MAINTENANCE et DISPONIBLE (sans chauffeur) ne produisent pas. */
    private boolean demandeUneAction(VehiculeStatus statut) {
        return statut == VehiculeStatus.IMMOBILISE
                || statut == VehiculeStatus.EN_MAINTENANCE
                || statut == VehiculeStatus.DISPONIBLE;
    }

    private VehiculeExceptionDto toException(Vehicule vehicule, VehiculeStatutHistorique periode) {
        VehiculeStatutMotif motif = periode != null && periode.getMotif() != null
                ? periode.getMotif()
                : motifParDefaut(vehicule.getStatut());
        Long jours = periode != null ? periode.joursDansStatut() : null;

        String libelle = ((vehicule.getMarque() != null ? vehicule.getMarque().getNom() : "") + " "
                + (vehicule.getModele() != null ? vehicule.getModele().getNom() : "")).trim();

        return new VehiculeExceptionDto(
                vehicule.getId(),
                vehicule.getImmatriculation(),
                libelle,
                vehicule.getStatut() != null ? vehicule.getStatut().name() : null,
                motif != null ? motif.name() : null,
                jours);
    }

    /** Motif déduit du statut quand la période historisée n'en porte pas (seed initial). */
    private VehiculeStatutMotif motifParDefaut(VehiculeStatus statut) {
        if (statut == null) return null;
        return switch (statut) {
            case DISPONIBLE -> VehiculeStatutMotif.SANS_CHAUFFEUR;
            case EN_MAINTENANCE -> VehiculeStatutMotif.MAINTENANCE_EN_COURS;
            default -> null;
        };
    }

    private EtatParcAlertesDto calculerAlertes(List<Vehicule> vehicules, LocalDate today, boolean filtreActif) {
        LocalDate horizonDocuments = today.plusDays(SEUIL_ALERTE_DOCUMENTS_JOURS);
        LocalDate horizonMaintenance = today.plusDays(SEUIL_ALERTE_MAINTENANCE_JOURS);

        List<Document> documents = documentRepository.findAll();

        // Sous filtre (groupe/activité), les documents véhicule sont restreints
        // au parc filtré. Sans filtre, le comptage reste global (inchangé).
        Set<Long> vehiculeIdsFiltres = vehicules.stream()
                .map(Vehicule::getId)
                .collect(Collectors.toSet());

        long documentsExpirant = documents.stream()
                .filter(d -> !Boolean.TRUE.equals(d.getPermanence()))
                // Expirés ou expirant dans les 30 prochains jours. Les permis
                // chauffeur déjà expirés sont exclus ici : ils sont comptés
                // séparément par `permisExpires` (pas de double comptage).
                .filter(d -> {
                    boolean expirantBientot = d.getDateExpiration() != null
                            && !d.getDateExpiration().isBefore(today)
                            && !d.getDateExpiration().isAfter(horizonDocuments);
                    boolean dejaExpire = d.estExpireLe(today)
                            && !(d.estPermis() && d.getCible() == CibleDocument.CHAUFFEUR);
                    return expirantBientot || dejaExpire;
                })
                .filter(d -> !filtreActif
                        || (d.getCible() == CibleDocument.VEHICULE
                                && vehiculeIdsFiltres.contains(d.getCibleId())))
                .count();

        long permisExpires = documents.stream()
                .filter(Document::estPermis)
                .filter(d -> d.getCible() == CibleDocument.CHAUFFEUR)
                .filter(d -> d.estExpireLe(today))
                .map(Document::getCibleId)
                .distinct()
                .count();

        long maintenancesDues = vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .filter(v -> v.getDateProchaineMaintenance() != null
                        && !v.getDateProchaineMaintenance().isAfter(horizonMaintenance))
                .count();

        return new EtatParcAlertesDto((int) documentsExpirant, (int) maintenancesDues, (int) permisExpires);
    }

    private BigDecimal pourcentage(int numerateur, int denominateur) {
        if (denominateur == 0) return BigDecimal.ZERO;
        return BigDecimal.valueOf(numerateur * 100L)
                .divide(BigDecimal.valueOf(denominateur), 1, RoundingMode.HALF_UP);
    }
}
