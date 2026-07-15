package com.tmk.vtcmanager.interfaces.rest.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.finance.CompteCourant;
import com.tmk.vtcmanager.application.usecases.arrete.AnnulerArreteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.ArreterCompteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.CalculerCompteCourantUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.GetArreteDecompteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.GetArreteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.GetCompteCourantUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.SelectionArrete;
import com.tmk.vtcmanager.interfaces.rest.arrete.dto.request.ArreterCompteRequest;
import com.tmk.vtcmanager.interfaces.rest.arrete.dto.response.ArreteResponse;
import com.tmk.vtcmanager.interfaces.rest.arrete.dto.response.CompteCourantResponse;
import com.tmk.vtcmanager.interfaces.rest.arrete.dto.response.LigneArreteResponse;
import com.tmk.vtcmanager.interfaces.rest.arrete.dto.response.ReglementArreteResponse;
import com.tmk.vtcmanager.interfaces.rest.common.AnnulationRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** Restitution des cotisations : comptes courants + arrêtés de compte. */
@RestController
@RequestMapping("/api/finances")
@RequiredArgsConstructor
public class ArreteCompteController {

    private final GetCompteCourantUseCase getCompteCourantUseCase;
    private final CalculerCompteCourantUseCase calculerCompteCourantUseCase;
    private final ArreterCompteUseCase arreterCompteUseCase;
    private final AnnulerArreteUseCase annulerArreteUseCase;
    private final GetArreteUseCase getArreteUseCase;
    private final GetArreteDecompteUseCase getArreteDecompteUseCase;

    /** Soldes de compte courant, par chauffeur (défaut) ou par véhicule. */
    @GetMapping("/compte-courant")
    public List<CompteCourantResponse> getComptesCourants(
            @RequestParam(defaultValue = "CHAUFFEUR") PerimetreArrete perimetre) {
        return getCompteCourantUseCase.lister(perimetre).stream()
                .map(ArreteCompteController::toCompteCourant)
                .toList();
    }

    /** Aperçu (non persisté) du décompte d'un arrêté sur une période. */
    @GetMapping("/arretes/apercu")
    public ArreteResponse apercu(
            @RequestParam PerimetreArrete perimetre,
            @RequestParam Long perimetreId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {
        return toArrete(calculerCompteCourantUseCase.construireApercu(perimetre, perimetreId, debut, fin));
    }

    /** Exécute l'arrêté : compensation + décaissement du net + cotisations RESTITUEE. */
    @PostMapping("/arretes")
    @ResponseStatus(HttpStatus.CREATED)
    public ArreteResponse arreter(@Valid @RequestBody ArreterCompteRequest request) {
        ArreteCompte arrete = arreterCompteUseCase.executer(
                request.perimetre(), request.perimetreId(),
                request.periodeDebut(), request.periodeFin(),
                request.dateArrete(), request.modePaiement(), request.compteTresorerieId(),
                toSelection(request));
        return toArrete(arrete);
    }

    /** Mappe la sélection de la requête (null = arrêté total, cf. {@link SelectionArrete#tout()}). */
    private static SelectionArrete toSelection(ArreterCompteRequest request) {
        Set<Long> cotisationIds = request.cotisationIds() == null ? null
                : new HashSet<>(request.cotisationIds());
        Set<SelectionArrete.CreanceKey> creances = request.creances() == null ? null
                : request.creances().stream()
                        .map(c -> new SelectionArrete.CreanceKey(c.document(), c.documentId()))
                        .collect(Collectors.toSet());
        return new SelectionArrete(cotisationIds, creances);
    }

    @GetMapping("/arretes")
    public List<ArreteResponse> lister() {
        return getArreteUseCase.lister().stream()
                .map(ArreteCompteController::toArrete)
                .toList();
    }

    @GetMapping("/arretes/{id}")
    public ArreteResponse detail(@PathVariable Long id) {
        return getArreteUseCase.detail(id)
                .map(ArreteCompteController::toArrete)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Arrêté introuvable : " + id));
    }

    /** Relevé de compte d'un chauffeur : tous les arrêtés où il est bénéficiaire. */
    @GetMapping("/arretes/chauffeur/{chauffeurId}")
    public List<ArreteResponse> releve(@PathVariable Long chauffeurId) {
        return getArreteUseCase.parBeneficiaire(chauffeurId).stream()
                .map(ArreteCompteController::toArrete)
                .toList();
    }

    /** Annule un arrêté (motif obligatoire) : contre-passe toutes ses écritures. */
    @PatchMapping("/arretes/{id}/annuler")
    public ArreteResponse annuler(@PathVariable Long id, @Valid @RequestBody AnnulationRequest request) {
        return toArrete(annulerArreteUseCase.executer(id, request.motif()));
    }

    /** Décompte PDF de l'arrêté. */
    @GetMapping("/arretes/{id}/pdf")
    public ResponseEntity<byte[]> decomptePdf(@PathVariable Long id) {
        byte[] pdf = getArreteDecompteUseCase.executer(id);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=decompte_arrete_" + id + ".pdf")
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdf);
    }

    // ── Mapping ──────────────────────────────────────────────────────────────

    public static CompteCourantResponse toCompteCourant(CompteCourant c) {
        return new CompteCourantResponse(c.getTiersId(), c.getLibelle(), c.getFondsCotisation(),
                c.getDu0a7Jours(), c.getDu8a30Jours(), c.getDuPlus30Jours(),
                c.getTotalCreances(), c.getNet());
    }

    public static ArreteResponse toArrete(ArreteCompte a) {
        List<ReglementArreteResponse> reglements = a.getReglements().stream()
                .map(r -> new ReglementArreteResponse(r.getChauffeurId(), r.getChauffeurNom(),
                        r.getTotalCotisations(), r.getTotalCreancesCompensees(), r.getMontantNet(),
                        r.getReliquatReporte(), r.getModePaiement(), r.getCompteTresorerieId(),
                        r.getOperationDecaissementId()))
                .toList();
        List<LigneArreteResponse> lignes = a.getLignes().stream()
                .map(l -> new LigneArreteResponse(l.getDocument(), l.getDocumentId(),
                        l.getChauffeurId(), l.getVehiculeId(), l.getImmatriculation(),
                        l.getMontant(), l.getSens()))
                .toList();

        String libelle = a.getPerimetreLibelle();
        if (libelle == null && a.getPerimetre() == PerimetreArrete.CHAUFFEUR && reglements.size() == 1) {
            libelle = reglements.get(0).chauffeurNom();
        }

        return new ArreteResponse(a.getId(), a.getPerimetre(), a.getPerimetreId(), libelle,
                a.getPeriodeDebut(), a.getPeriodeFin(), a.getDateArrete(), a.getReference(),
                a.getStatut() != null ? a.getStatut().name() : null, a.getMotifAnnulation(),
                a.totalRestitue(), a.getResteNet(), lignes, reglements);
    }
}
