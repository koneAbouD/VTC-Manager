package com.tmk.vtcmanager.application.usecases.etatparc;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeStatutHistoriqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
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
    /** Échéance sous laquelle une maintenance planifiée fait entrer le véhicule
     *  dans la liste « demandant une action ». */
    private static final int SEUIL_ACTION_MAINTENANCE_PREVUE_JOURS = 4;
    private static final int SEUIL_ALERTE_VIDANGE_JOURS = 7;
    /** Km restants sous lesquels une vidange est réputée due (déclenche l'alerte). */
    private static final int SEUIL_ALERTE_VIDANGE_KM = 500;

    private final VehiculeRepository vehiculeRepository;
    private final VehiculeStatutHistoriqueRepository statutHistoriqueRepository;
    private final DocumentRepository documentRepository;
    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final VidangeRepository vidangeRepository;
    private final MaintenanceRepository maintenanceRepository;

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

        // Fin prévue des immobilisations planifiées couvrant aujourd'hui (indisponibilité
        // véhicule). Une seule lecture par statut, sans requête par véhicule (pas de N+1).
        Map<Long, LocalDate> finsPrevues = finsPrevuesParVehicule(today);

        List<VehiculeExceptionDto> exceptionsStatut = vehicules.stream()
                .filter(v -> demandeUneAction(v.getStatut()))
                .map(v -> toException(v, periodesEnCours.get(v.getId()), finsPrevues.get(v.getId())))
                .sorted(Comparator.comparing(VehiculeExceptionDto::joursDansStatut,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();

        // Véhicules dont au moins une maintenance planifiée est proche (≤ 4 j) mais
        // qui ne figurent pas déjà dans la liste au titre de leur statut (pas de doublon).
        Set<Long> dejaListes = exceptionsStatut.stream()
                .map(VehiculeExceptionDto::vehiculeId)
                .collect(Collectors.toSet());
        List<VehiculeExceptionDto> exceptionsMaintenancePrevue =
                maintenancesPrevues(vehicules, today, dejaListes);

        List<VehiculeExceptionDto> exceptions = new java.util.ArrayList<>(exceptionsStatut);
        exceptions.addAll(exceptionsMaintenancePrevue);

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

    private VehiculeExceptionDto toException(Vehicule vehicule, VehiculeStatutHistorique periode,
                                             LocalDate finPrevue) {
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
                jours,
                finPrevue,
                null);
    }

    /**
     * Véhicules du parc filtré (HORS_PARC exclu) ayant au moins une maintenance
     * PLANIFIEE dont l'échéance tombe sous {@value #SEUIL_ACTION_MAINTENANCE_PREVUE_JOURS} j
     * (échéances déjà dépassées incluses). Un véhicule déjà présent dans
     * {@code dejaListes} (au titre de son statut) est ignoré pour éviter les doublons.
     * Une seule entrée par véhicule, sur la maintenance la plus proche.
     */
    private List<VehiculeExceptionDto> maintenancesPrevues(List<Vehicule> vehicules, LocalDate today,
                                                           Set<Long> dejaListes) {
        Map<Long, Vehicule> parcFiltre = vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .collect(Collectors.toMap(Vehicule::getId, Function.identity(), (a, b) -> a));
        if (parcFiltre.isEmpty()) return List.of();

        LocalDate horizon = today.plusDays(SEUIL_ACTION_MAINTENANCE_PREVUE_JOURS);

        // Échéance la plus proche par véhicule éligible.
        Map<Long, LocalDate> echeances = new java.util.HashMap<>();
        maintenanceRepository
                .findByDatePrevueLessThanEqualAndStatut(horizon, MaintenanceStatus.PLANIFIEE)
                .forEach(m -> {
                    if (m.getVehicule() == null || m.getDatePrevue() == null) return;
                    Long vehiculeId = m.getVehicule().getId();
                    if (!parcFiltre.containsKey(vehiculeId) || dejaListes.contains(vehiculeId)) return;
                    echeances.merge(vehiculeId, m.getDatePrevue(),
                            (a, b) -> a.isBefore(b) ? a : b);
                });

        return echeances.entrySet().stream()
                .sorted(Map.Entry.comparingByValue())
                .map(e -> {
                    Vehicule v = parcFiltre.get(e.getKey());
                    String libelle = ((v.getMarque() != null ? v.getMarque().getNom() : "") + " "
                            + (v.getModele() != null ? v.getModele().getNom() : "")).trim();
                    return new VehiculeExceptionDto(
                            v.getId(),
                            v.getImmatriculation(),
                            libelle,
                            v.getStatut() != null ? v.getStatut().name() : null,
                            VehiculeStatutMotif.MAINTENANCE_PREVUE.name(),
                            null,
                            null,
                            e.getValue());
                })
                .toList();
    }

    /**
     * Fin prévue (date_fin) des indisponibilités véhicule couvrant {@code today},
     * par véhicule. Si plusieurs se chevauchent, on retient la plus lointaine
     * (le véhicule reste immobilisé jusqu'à la dernière). Les immobilisations
     * ouvertes (date_fin null) n'alimentent pas la map.
     */
    private Map<Long, LocalDate> finsPrevuesParVehicule(LocalDate today) {
        Map<Long, LocalDate> fins = new java.util.HashMap<>();
        for (IndisponibiliteStatut statut : List.of(IndisponibiliteStatut.EN_COURS,
                IndisponibiliteStatut.PLANIFIEE)) {
            for (IndisponibiliteVehicule i : indisponibiliteVehiculeRepository.findByStatut(statut)) {
                if (i.getVehiculeId() == null || i.getDateDebut() == null) continue;
                if (i.getDateDebut().isAfter(today)) continue;
                if (i.getDateFin() != null && i.getDateFin().isBefore(today)) continue;
                if (i.getDateFin() == null) continue; // immobilisation ouverte : pas de fin prévue
                fins.merge(i.getVehiculeId(), i.getDateFin(),
                        (a, b) -> a.isAfter(b) ? a : b);
            }
        }
        return fins;
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

        long maintenancesDues = compterMaintenancesDues(vehicules, horizonMaintenance);

        long vidangesDues = compterVidangesDues(vehicules, today);

        return new EtatParcAlertesDto(
                (int) documentsExpirant, (int) maintenancesDues, (int) permisExpires,
                (int) vidangesDues);
    }

    /**
     * Compte les lignes de maintenance <b>planifiées</b> (statut PLANIFIEE) dont la
     * date prévue est échue ou tombe sous {@value #SEUIL_ALERTE_MAINTENANCE_JOURS} j,
     * rattachées à un véhicule du parc actif filtré (HORS_PARC exclu). Contrairement
     * au champ {@code dateProchaineMaintenance} du véhicule (jamais recalculé après
     * complétion), cette source reflète l'état réel des maintenances à venir.
     */
    private long compterMaintenancesDues(List<Vehicule> vehicules, LocalDate horizon) {
        Set<Long> parcActifIds = vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .map(Vehicule::getId)
                .collect(Collectors.toSet());
        if (parcActifIds.isEmpty()) return 0;

        return maintenanceRepository
                .findByDatePrevueLessThanEqualAndStatut(horizon, MaintenanceStatus.PLANIFIEE)
                .stream()
                .filter(m -> m.getVehicule() != null
                        && parcActifIds.contains(m.getVehicule().getId()))
                .count();
    }

    /**
     * Compte les véhicules (parc actif) dont la dernière vidange indique qu'une
     * prochaine vidange est due, soit par la date prévue (≤ {@value #SEUIL_ALERTE_VIDANGE_JOURS} j,
     * y compris en retard), soit par le kilométrage (km cible atteint à
     * {@value #SEUIL_ALERTE_VIDANGE_KM} km près du km actuel du véhicule). Une seule
     * lecture des dernières vidanges (pas de N+1).
     */
    private long compterVidangesDues(List<Vehicule> vehicules, LocalDate today) {
        Map<Long, Vidange> dernieres = vidangeRepository.findDernieresParVehicule().stream()
                .filter(v -> v.getVehiculeId() != null)
                .collect(Collectors.toMap(Vidange::getVehiculeId, Function.identity(),
                        (a, b) -> a));
        LocalDate horizonVidange = today.plusDays(SEUIL_ALERTE_VIDANGE_JOURS);

        return vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .filter(v -> vidangeDue(dernieres.get(v.getId()), v.getKilometrage(), horizonVidange))
                .count();
    }

    /** Vraie si la vidange est due par date (≤ horizon) ou par kilométrage restant. */
    private boolean vidangeDue(Vidange derniere, Integer kilometrageActuel, LocalDate horizon) {
        if (derniere == null) return false;
        LocalDate dateProchaine = derniere.getDateProchaineVidange();
        if (dateProchaine != null && !dateProchaine.isAfter(horizon)) {
            return true;
        }
        Integer kmCible = derniere.getKilometrageProchaineVidange();
        return kmCible != null && kilometrageActuel != null
                && (kmCible - kilometrageActuel) <= SEUIL_ALERTE_VIDANGE_KM;
    }

    private BigDecimal pourcentage(int numerateur, int denominateur) {
        if (denominateur == 0) return BigDecimal.ZERO;
        return BigDecimal.valueOf(numerateur * 100L)
                .divide(BigDecimal.valueOf(denominateur), 1, RoundingMode.HALF_UP);
    }
}
