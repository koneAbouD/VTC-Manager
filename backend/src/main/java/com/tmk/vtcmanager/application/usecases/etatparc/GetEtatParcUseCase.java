package com.tmk.vtcmanager.application.usecases.etatparc;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
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
    /** Horizon commun aux maintenances planifiées : une échéance échue ou due
     *  sous ce délai alimente à la fois l'alerte préventive « maintenances dues »
     *  et la liste des véhicules « demandant une action ». */
    private static final int SEUIL_ALERTE_MAINTENANCE_JOURS = 7;
    private static final int SEUIL_ALERTE_VIDANGE_JOURS = 7;
    /** Km restants sous lesquels une vidange est réputée due (déclenche l'alerte). */
    private static final int SEUIL_ALERTE_VIDANGE_KM = 500;

    /** Écran vers lequel ouvrir une ligne de la liste (voir {@link VehiculeExceptionDto}). */
    private static final String CIBLE_VEHICULE = "VEHICULE";
    private static final String CIBLE_MAINTENANCE = "MAINTENANCE";
    private static final String CIBLE_INDISPONIBILITE = "INDISPONIBILITE_VEHICULE";
    private static final String CIBLE_PENALITE = "PENALITE";
    private static final String CIBLE_VIDANGE = "VIDANGE";

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

        // Immobilisation planifiée couvrant aujourd'hui (indisponibilité véhicule) :
        // elle porte la fin prévue et l'écran vers lequel ouvrir la ligne. Une seule
        // lecture par statut, sans requête par véhicule (pas de N+1).
        Map<Long, IndisponibiliteVehicule> immobilisations = immobilisationsDuJour(today);

        // Maintenance en cours par véhicule : la ligne « maintenance en cours » ouvre
        // sur l'intervention elle-même.
        Map<Long, Maintenance> maintenancesEnCours = maintenanceRepository
                .findByStatut(MaintenanceStatus.EN_COURS).stream()
                .filter(m -> m.getVehicule() != null && m.getVehicule().getId() != null)
                .collect(Collectors.toMap(m -> m.getVehicule().getId(), Function.identity(),
                        (a, b) -> a));

        // Maintenances planifiées échues ou dues sous l'horizon commun : une seule
        // lecture, partagée par la liste « demandant une action » et l'alerte
        // préventive (les deux raisonnent ainsi sur le même horizon).
        List<Maintenance> maintenancesPlanifiees = maintenanceRepository
                .findByDatePrevueLessThanEqualAndStatut(
                        today.plusDays(SEUIL_ALERTE_MAINTENANCE_JOURS),
                        MaintenanceStatus.PLANIFIEE);

        List<VehiculeExceptionDto> exceptionsStatut = vehicules.stream()
                .filter(v -> demandeUneAction(v.getStatut()))
                .map(v -> toException(v, periodesEnCours.get(v.getId()),
                        immobilisations.get(v.getId()), maintenancesEnCours.get(v.getId())))
                .sorted(Comparator.comparing(VehiculeExceptionDto::joursDansStatut,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();

        // Dernière vidange par véhicule : une seule lecture, partagée par la liste
        // « demandant une action » et l'alerte préventive (pas de N+1).
        Map<Long, Vidange> dernieresVidanges = vidangeRepository.findDernieresParVehicule()
                .stream()
                .filter(v -> v.getVehiculeId() != null)
                .collect(Collectors.toMap(Vidange::getVehiculeId, Function.identity(),
                        (a, b) -> a));

        // Les blocs suivants sont indépendants du statut : un véhicule qui appelle
        // plusieurs actions porte une ligne par motif, pour qu'un filtre sur l'un
        // d'eux les montre tous (un immobilisé à vidanger reste à vidanger).
        // Véhicules dont au moins une maintenance planifiée est proche (≤ 7 j).
        List<VehiculeExceptionDto> exceptionsMaintenancePrevue =
                maintenancesPrevues(maintenancesPlanifiees, vehicules);

        // Véhicules dont la vidange est due (par date ou par kilométrage).
        List<VehiculeExceptionDto> exceptionsVidange =
                vidangesDues(vehicules, dernieresVidanges, today);

        List<VehiculeExceptionDto> exceptions = new java.util.ArrayList<>(exceptionsStatut);
        exceptions.addAll(exceptionsMaintenancePrevue);
        exceptions.addAll(exceptionsVidange);

        return new EtatParcSummaryResponse(
                vehicules.size(), parcActif,
                enService, disponibles, enMaintenance, immobilises, horsParc,
                tauxDisponibilite, tauxUtilisation,
                exceptions,
                calculerAlertes(vehicules, today, filtreActif, maintenancesPlanifiees,
                        dernieresVidanges));
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
                                             IndisponibiliteVehicule immobilisation,
                                             Maintenance maintenanceEnCours) {
        VehiculeStatutMotif motif = periode != null && periode.getMotif() != null
                ? periode.getMotif()
                : motifParDefaut(vehicule.getStatut());
        Long jours = periode != null ? periode.joursDansStatut() : null;

        // Chaque motif ouvre sur l'objet qui explique l'arrêt, à défaut sur le véhicule.
        String cible = CIBLE_VEHICULE;
        Long cibleId = null;
        if (motif == VehiculeStatutMotif.IMMOBILISATION_INDISPONIBILITE && immobilisation != null) {
            cible = CIBLE_INDISPONIBILITE;
            cibleId = immobilisation.getId();
        } else if (motif == VehiculeStatutMotif.MAINTENANCE_EN_COURS && maintenanceEnCours != null) {
            cible = CIBLE_MAINTENANCE;
            cibleId = maintenanceEnCours.getId();
        } else if (motif == VehiculeStatutMotif.IMMOBILISATION_PENALITE) {
            // Aucune ligne de pénalité ne porte à elle seule l'immobilisation :
            // la ligne ouvre sur les pénalités du véhicule.
            cible = CIBLE_PENALITE;
        }

        return new VehiculeExceptionDto(
                vehicule.getId(),
                vehicule.getImmatriculation(),
                libelleVehicule(vehicule),
                vehicule.getStatut() != null ? vehicule.getStatut().name() : null,
                motif != null ? motif.name() : null,
                jours,
                immobilisation != null ? immobilisation.getDateFin() : null,
                null, null, null,
                cible, cibleId);
    }

    /** « Marque Modèle », vide si le véhicule n'en porte pas. */
    private String libelleVehicule(Vehicule vehicule) {
        return ((vehicule.getMarque() != null ? vehicule.getMarque().getNom() : "") + " "
                + (vehicule.getModele() != null ? vehicule.getModele().getNom() : "")).trim();
    }

    /**
     * Véhicules du parc filtré (HORS_PARC exclu) ayant au moins une maintenance
     * PLANIFIEE dont l'échéance tombe sous {@value #SEUIL_ALERTE_MAINTENANCE_JOURS} j
     * (échéances déjà dépassées incluses) — même horizon, même périmètre et même
     * unité que l'alerte préventive « maintenances dues ». Une seule entrée par
     * véhicule, sur la maintenance la plus proche ; le véhicule peut par ailleurs
     * figurer dans la liste sous un autre motif (statut, vidange).
     */
    private List<VehiculeExceptionDto> maintenancesPrevues(List<Maintenance> maintenancesPlanifiees,
                                                           List<Vehicule> vehicules) {
        Map<Long, Vehicule> parcFiltre = vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .collect(Collectors.toMap(Vehicule::getId, Function.identity(), (a, b) -> a));
        if (parcFiltre.isEmpty()) return List.of();

        // Maintenance la plus proche par véhicule éligible : c'est elle que la ligne
        // affiche et sur laquelle elle ouvre.
        Map<Long, Maintenance> prochaines = new java.util.HashMap<>();
        maintenancesPlanifiees.forEach(m -> {
            if (m.getVehicule() == null || m.getDatePrevue() == null) return;
            Long vehiculeId = m.getVehicule().getId();
            if (!parcFiltre.containsKey(vehiculeId)) return;
            prochaines.merge(vehiculeId, m,
                    (a, b) -> a.getDatePrevue().isBefore(b.getDatePrevue()) ? a : b);
        });

        return prochaines.entrySet().stream()
                .sorted(Comparator.comparing(e -> e.getValue().getDatePrevue()))
                .map(e -> {
                    Vehicule v = parcFiltre.get(e.getKey());
                    Maintenance m = e.getValue();
                    return new VehiculeExceptionDto(
                            v.getId(),
                            v.getImmatriculation(),
                            libelleVehicule(v),
                            v.getStatut() != null ? v.getStatut().name() : null,
                            VehiculeStatutMotif.MAINTENANCE_PREVUE.name(),
                            null,
                            null,
                            m.getDatePrevue(),
                            null, null,
                            CIBLE_MAINTENANCE, m.getId());
                })
                .toList();
    }

    /**
     * Véhicules du parc filtré (HORS_PARC exclu) dont la vidange est due — par date
     * (≤ {@value #SEUIL_ALERTE_VIDANGE_JOURS} j, retards inclus) ou par kilométrage
     * (cible atteinte à {@value #SEUIL_ALERTE_VIDANGE_KM} km près). Même règle et
     * même périmètre que l'alerte préventive « vidanges prévues », qui compte
     * exactement ces véhicules. Triés par échéance la plus proche, les dues au seul
     * kilométrage en dernier. Le véhicule peut par ailleurs figurer dans la liste
     * sous un autre motif (statut, maintenance).
     */
    private List<VehiculeExceptionDto> vidangesDues(List<Vehicule> vehicules,
                                                    Map<Long, Vidange> dernieresVidanges,
                                                    LocalDate today) {
        LocalDate horizon = today.plusDays(SEUIL_ALERTE_VIDANGE_JOURS);

        return vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .filter(v -> vidangeDue(dernieresVidanges.get(v.getId()), v.getKilometrage(),
                        horizon))
                .sorted(Comparator.comparing(
                        (Vehicule v) -> dernieresVidanges.get(v.getId()).getDateProchaineVidange(),
                        Comparator.nullsLast(Comparator.naturalOrder())))
                .map(v -> toExceptionVidange(v, dernieresVidanges.get(v.getId())))
                .toList();
    }

    private VehiculeExceptionDto toExceptionVidange(Vehicule vehicule, Vidange derniere) {
        Integer kmCible = derniere.getKilometrageProchaineVidange();
        Integer kmRestant = kmCible != null && vehicule.getKilometrage() != null
                ? kmCible - vehicule.getKilometrage()
                : null;

        return new VehiculeExceptionDto(
                vehicule.getId(),
                vehicule.getImmatriculation(),
                libelleVehicule(vehicule),
                vehicule.getStatut() != null ? vehicule.getStatut().name() : null,
                VehiculeStatutMotif.VIDANGE_DUE.name(),
                null,
                null,
                null,
                derniere.getDateProchaineVidange(),
                kmRestant,
                CIBLE_VIDANGE, null);
    }

    /**
     * Indisponibilité véhicule couvrant {@code today}, par véhicule : elle porte la
     * fin prévue affichée sur la ligne et l'écran sur lequel celle-ci ouvre. Si
     * plusieurs se chevauchent, on retient celle qui libère le véhicule le plus tard
     * — une immobilisation ouverte (date_fin null) prime, le véhicule n'ayant alors
     * aucune fin prévue.
     */
    private Map<Long, IndisponibiliteVehicule> immobilisationsDuJour(LocalDate today) {
        Map<Long, IndisponibiliteVehicule> couvrantes = new java.util.HashMap<>();
        for (IndisponibiliteStatut statut : List.of(IndisponibiliteStatut.EN_COURS,
                IndisponibiliteStatut.PLANIFIEE)) {
            for (IndisponibiliteVehicule i : indisponibiliteVehiculeRepository.findByStatut(statut)) {
                if (i.getVehiculeId() == null || i.getDateDebut() == null) continue;
                if (i.getDateDebut().isAfter(today)) continue;
                if (i.getDateFin() != null && i.getDateFin().isBefore(today)) continue;
                couvrantes.merge(i.getVehiculeId(), i, GetEtatParcUseCase::laPlusLointaine);
            }
        }
        return couvrantes;
    }

    /** Des deux immobilisations, celle qui libère le véhicule le plus tard. */
    private static IndisponibiliteVehicule laPlusLointaine(IndisponibiliteVehicule a,
                                                           IndisponibiliteVehicule b) {
        if (a.getDateFin() == null || b.getDateFin() == null) {
            return a.getDateFin() == null ? a : b;
        }
        return a.getDateFin().isAfter(b.getDateFin()) ? a : b;
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

    private EtatParcAlertesDto calculerAlertes(List<Vehicule> vehicules, LocalDate today,
                                               boolean filtreActif,
                                               List<Maintenance> maintenancesPlanifiees,
                                               Map<Long, Vidange> dernieresVidanges) {
        LocalDate horizonDocuments = today.plusDays(SEUIL_ALERTE_DOCUMENTS_JOURS);

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

        long maintenancesDues = compterMaintenancesDues(vehicules, maintenancesPlanifiees);

        long vidangesDues = compterVidangesDues(vehicules, dernieresVidanges, today);

        return new EtatParcAlertesDto(
                (int) documentsExpirant, (int) maintenancesDues, (int) permisExpires,
                (int) vidangesDues);
    }

    /**
     * Compte les <b>véhicules</b> du parc actif filtré (HORS_PARC exclu) ayant au
     * moins une maintenance PLANIFIEE échue ou due sous
     * {@value #SEUIL_ALERTE_MAINTENANCE_JOURS} j : un véhicule portant plusieurs
     * échéances proches ne compte qu'une fois, comme dans la liste « demandant une
     * action », qui s'appuie sur le même horizon et le même périmètre.
     * <p>
     * Contrairement au champ {@code dateProchaineMaintenance} du véhicule (jamais
     * recalculé après complétion), cette source reflète l'état réel des maintenances
     * à venir.
     */
    private long compterMaintenancesDues(List<Vehicule> vehicules,
                                         List<Maintenance> maintenancesPlanifiees) {
        Set<Long> parcActifIds = vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .map(Vehicule::getId)
                .collect(Collectors.toSet());
        if (parcActifIds.isEmpty()) return 0;

        return maintenancesPlanifiees.stream()
                .filter(m -> m.getVehicule() != null
                        && parcActifIds.contains(m.getVehicule().getId()))
                .map(m -> m.getVehicule().getId())
                .distinct()
                .count();
    }

    /**
     * Compte les véhicules (parc actif) dont la dernière vidange indique qu'une
     * prochaine vidange est due, soit par la date prévue (≤ {@value #SEUIL_ALERTE_VIDANGE_JOURS} j,
     * y compris en retard), soit par le kilométrage (km cible atteint à
     * {@value #SEUIL_ALERTE_VIDANGE_KM} km près du km actuel du véhicule). Mêmes
     * véhicules que le bloc {@code VIDANGE_DUE} de la liste « demandant une action ».
     */
    private long compterVidangesDues(List<Vehicule> vehicules,
                                     Map<Long, Vidange> dernieresVidanges, LocalDate today) {
        LocalDate horizonVidange = today.plusDays(SEUIL_ALERTE_VIDANGE_JOURS);

        return vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .filter(v -> vidangeDue(dernieresVidanges.get(v.getId()), v.getKilometrage(),
                        horizonVidange))
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
