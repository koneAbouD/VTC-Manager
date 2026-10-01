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
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.ActionVehiculeDto;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcAlertesDto;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcSummaryResponse;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.VehiculeExceptionDto;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.HashMap;
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

    /**
     * Ordre de la liste : rang de l'action principale (arrêts, maintenances
     * prévues, vidanges), puis les arrêts les plus anciens, puis les échéances
     * les plus proches — les vidanges dues au seul kilométrage en dernier.
     */
    private static final Comparator<VehiculeExceptionDto> ORDRE_LISTE = Comparator
            .comparingInt((VehiculeExceptionDto e) -> rang(e.motif()))
            .thenComparing(VehiculeExceptionDto::joursDansStatut,
                    Comparator.nullsLast(Comparator.reverseOrder()))
            .thenComparing(VehiculeExceptionDto::dateMaintenancePrevue,
                    Comparator.nullsLast(Comparator.naturalOrder()))
            .thenComparing(VehiculeExceptionDto::dateProchaineVidange,
                    Comparator.nullsLast(Comparator.naturalOrder()));

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

        // Dernière vidange par véhicule : une seule lecture, partagée par la liste
        // « demandant une action » et l'alerte préventive (pas de N+1).
        Map<Long, Vidange> dernieresVidanges = vidangeRepository.findDernieresParVehicule()
                .stream()
                .filter(v -> v.getVehiculeId() != null)
                .collect(Collectors.toMap(Vidange::getVehiculeId, Function.identity(),
                        (a, b) -> a));

        // Les actions préventives (maintenance, vidange) portent sur le parc filtré
        // hors HORS_PARC — même périmètre que les alertes préventives.
        Set<Long> parcActifIds = vehicules.stream()
                .filter(v -> v.getStatut() != VehiculeStatus.HORS_PARC)
                .map(Vehicule::getId)
                .collect(Collectors.toSet());

        // Véhicules dont la vidange est due (par date ou par kilométrage).
        LocalDate horizonVidange = today.plusDays(SEUIL_ALERTE_VIDANGE_JOURS);
        Set<Long> vidangesDues = vehicules.stream()
                .filter(v -> parcActifIds.contains(v.getId()))
                .filter(v -> vidangeDue(dernieresVidanges.get(v.getId()), v.getKilometrage(),
                        horizonVidange))
                .map(Vehicule::getId)
                .collect(Collectors.toSet());

        // Maintenance planifiée la plus proche par véhicule. Une maintenance
        // « Vidange » sur un véhicule dont la vidange est due est cette vidange même
        // (le rappel automatique la planifie à l'échéance) : elle porte l'action
        // vidange au lieu d'apparaître une seconde fois en « maintenance prévue ».
        Map<Long, Maintenance> maintenancesPrevues = new HashMap<>();
        Map<Long, Maintenance> vidangesPlanifiees = new HashMap<>();
        for (Maintenance m : maintenancesPlanifiees) {
            if (m.getVehicule() == null || m.getDatePrevue() == null) continue;
            Long vehiculeId = m.getVehicule().getId();
            if (!parcActifIds.contains(vehiculeId)) continue;
            Map<Long, Maintenance> destination =
                    m.estVidange() && vidangesDues.contains(vehiculeId)
                            ? vidangesPlanifiees
                            : maintenancesPrevues;
            destination.merge(vehiculeId, m, GetEtatParcUseCase::laPlusProche);
        }

        // Une seule ligne par véhicule, portant toutes ses actions — l'arrêt de
        // production d'abord, puis la maintenance prévue, puis la vidange. Le filtre
        // par motif côté client retient un véhicule dès qu'une de ses actions
        // correspond (un immobilisé à vidanger reste à vidanger).
        List<VehiculeExceptionDto> exceptions = new ArrayList<>();
        for (Vehicule v : vehicules) {
            List<ActionVehiculeDto> actions = new ArrayList<>(3);
            Long jours = null;
            if (demandeUneAction(v.getStatut())) {
                VehiculeStatutHistorique periode = periodesEnCours.get(v.getId());
                jours = periode != null ? periode.joursDansStatut() : null;
                actions.add(actionStatut(v, periode, immobilisations.get(v.getId()),
                        maintenancesEnCours.get(v.getId())));
            }
            Maintenance prevue = maintenancesPrevues.get(v.getId());
            if (prevue != null) {
                actions.add(actionMaintenancePrevue(prevue));
            }
            if (vidangesDues.contains(v.getId())) {
                actions.add(actionVidange(v, dernieresVidanges.get(v.getId()),
                        vidangesPlanifiees.get(v.getId())));
            }
            if (!actions.isEmpty()) {
                exceptions.add(toException(v, jours, actions));
            }
        }
        exceptions.sort(ORDRE_LISTE);

        return new EtatParcSummaryResponse(
                vehicules.size(), parcActif,
                enService, disponibles, enMaintenance, immobilises, horsParc,
                tauxDisponibilite, tauxUtilisation,
                exceptions,
                calculerAlertes(vehicules, today, filtreActif, maintenancesPrevues.size(),
                        vidangesDues.size()));
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

    /** Action portée par le statut improductif du véhicule (arrêt de production). */
    private ActionVehiculeDto actionStatut(Vehicule vehicule, VehiculeStatutHistorique periode,
                                           IndisponibiliteVehicule immobilisation,
                                           Maintenance maintenanceEnCours) {
        VehiculeStatutMotif motif = periode != null && periode.getMotif() != null
                ? periode.getMotif()
                : motifParDefaut(vehicule.getStatut());

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

        return new ActionVehiculeDto(
                motif != null ? motif.name() : null,
                immobilisation != null ? immobilisation.getDateFin() : null,
                null, null, null,
                cible, cibleId);
    }

    /** Maintenance planifiée la plus proche : la ligne affiche et ouvre celle-ci. */
    private ActionVehiculeDto actionMaintenancePrevue(Maintenance maintenance) {
        return new ActionVehiculeDto(
                VehiculeStatutMotif.MAINTENANCE_PREVUE.name(),
                null,
                maintenance.getDatePrevue(),
                null, null,
                CIBLE_MAINTENANCE, maintenance.getId());
    }

    /**
     * Vidange due. Déjà planifiée en maintenance, elle ouvre sur cette
     * intervention ; sinon sur l'historique des vidanges du véhicule.
     */
    private ActionVehiculeDto actionVidange(Vehicule vehicule, Vidange derniere,
                                            Maintenance vidangePlanifiee) {
        Integer kmCible = derniere.getKilometrageProchaineVidange();
        Integer kmRestant = kmCible != null && vehicule.getKilometrage() != null
                ? kmCible - vehicule.getKilometrage()
                : null;

        return new ActionVehiculeDto(
                VehiculeStatutMotif.VIDANGE_DUE.name(),
                null,
                null,
                derniere.getDateProchaineVidange(),
                kmRestant,
                vidangePlanifiee != null ? CIBLE_MAINTENANCE : CIBLE_VIDANGE,
                vidangePlanifiee != null ? vidangePlanifiee.getId() : null);
    }

    /** Ligne du véhicule : ses actions, la principale recopiée à plat. */
    private VehiculeExceptionDto toException(Vehicule vehicule, Long joursDansStatut,
                                             List<ActionVehiculeDto> actions) {
        ActionVehiculeDto principale = actions.get(0);
        return new VehiculeExceptionDto(
                vehicule.getId(),
                vehicule.getImmatriculation(),
                libelleVehicule(vehicule),
                vehicule.getStatut() != null ? vehicule.getStatut().name() : null,
                principale.motif(),
                joursDansStatut,
                principale.finPrevue(),
                principale.dateMaintenancePrevue(),
                principale.dateProchaineVidange(),
                principale.kmRestantVidange(),
                principale.cible(), principale.cibleId(),
                List.copyOf(actions));
    }

    /**
     * Rang de l'action principale dans la liste : arrêts de production (0), puis
     * maintenances prévues (1), puis vidanges dues (2).
     */
    private static int rang(String motif) {
        if (VehiculeStatutMotif.MAINTENANCE_PREVUE.name().equals(motif)) return 1;
        if (VehiculeStatutMotif.VIDANGE_DUE.name().equals(motif)) return 2;
        return 0;
    }

    /** Des deux maintenances planifiées, celle dont l'échéance tombe la première. */
    private static Maintenance laPlusProche(Maintenance a, Maintenance b) {
        return a.getDatePrevue().isBefore(b.getDatePrevue()) ? a : b;
    }

    /** « Marque Modèle », vide si le véhicule n'en porte pas. */
    private String libelleVehicule(Vehicule vehicule) {
        return ((vehicule.getMarque() != null ? vehicule.getMarque().getNom() : "") + " "
                + (vehicule.getModele() != null ? vehicule.getModele().getNom() : "")).trim();
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
                                               int maintenancesDues, int vidangesDues) {
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

        // Maintenances et vidanges dues : mêmes véhicules que les actions de la
        // liste. Une maintenance « Vidange » rattachée à la vidange due n'est
        // comptée qu'en vidange.
        return new EtatParcAlertesDto(
                (int) documentsExpirant, maintenancesDues, (int) permisExpires,
                vidangesDues);
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
