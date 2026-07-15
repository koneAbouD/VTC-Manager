package com.tmk.vtcmanager.interfaces.rest.selfservice;

import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.finance.CompteCourant;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.penalite.LignePenaliteFiltres;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.usecases.arrete.GetArreteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.GetArreteDecompteUseCase;
import com.tmk.vtcmanager.application.usecases.arrete.GetCompteCourantUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.GetAllContraventionsUseCase;
import com.tmk.vtcmanager.application.usecases.auth.SetChauffeurPasswordUseCase;
import com.tmk.vtcmanager.application.usecases.chauffeur.GetAllChauffeursUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.GetLignesCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibilite.CreateIndisponibiliteUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibilite.GetAllIndisponibilitesUseCase;
import com.tmk.vtcmanager.application.usecases.indisponibilite.TerminerIndisponibiliteUseCase;
import com.tmk.vtcmanager.application.usecases.operationFinanciere.GetAllOperationsFinancieresUseCase;
import com.tmk.vtcmanager.application.usecases.payment.GetStatutPaiementUseCase;
import com.tmk.vtcmanager.application.usecases.payment.InitierPaiementUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.GetLignesPenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.recette.GetLignesRecetteUseCase;
import com.tmk.vtcmanager.interfaces.rest.arrete.ArreteCompteController;
import com.tmk.vtcmanager.interfaces.rest.arrete.dto.response.ArreteResponse;
import com.tmk.vtcmanager.interfaces.rest.arrete.dto.response.CompteCourantResponse;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.mapper.ChauffeurRestMapper;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ContraventionResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.mapper.ContraventionRestMapper;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.LigneCotisationResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.mapper.CotisationRestMapper;
import com.tmk.vtcmanager.interfaces.rest.indisponibilite.dto.response.IndisponibiliteResponse;
import com.tmk.vtcmanager.interfaces.rest.indisponibilite.mapper.IndisponibiliteRestMapper;
import com.tmk.vtcmanager.interfaces.rest.selfservice.dto.IndisponibiliteSelfRequest;
import com.tmk.vtcmanager.interfaces.rest.selfservice.dto.RemplacantResponse;
import com.tmk.vtcmanager.interfaces.rest.payment.dto.PaiementRequest;
import com.tmk.vtcmanager.interfaces.rest.payment.dto.PaiementResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.OperationFinanciereResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper.OperationFinanciereRestMapper;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.response.LignePenaliteResponse;
import com.tmk.vtcmanager.interfaces.rest.penalite.mapper.PenaliteRestMapper;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.LigneRecetteResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.mapper.RecetteRestMapper;
import com.tmk.vtcmanager.interfaces.rest.selfservice.dto.SetPasswordDto;
import com.tmk.vtcmanager.interfaces.rest.selfservice.dto.SoldeResponse;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.validation.Valid;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.List;

/**
 * API self-service de l'app chauffeur. Toutes les données sont cadrées sur le
 * chauffeur du token (résolu par {@link CurrentChauffeurResolver}) : aucun
 * identifiant n'est accepté du client, ce qui exclut tout accès transverse.
 */
@RestController
@RequestMapping("/api/me")
@RequiredArgsConstructor
@Tag(name = "Self-service chauffeur", description = "Données du chauffeur connecté (app mobile)")
public class SelfServiceController {

    private final CurrentChauffeurResolver currentChauffeur;
    private final SetChauffeurPasswordUseCase setChauffeurPasswordUseCase;
    private final GetLignesRecetteUseCase getLignesRecetteUseCase;
    private final GetLignesCotisationUseCase getLignesCotisationUseCase;
    private final GetAllContraventionsUseCase getAllContraventionsUseCase;
    private final GetLignesPenaliteUseCase getLignesPenaliteUseCase;
    private final GetAllOperationsFinancieresUseCase getAllOperationsFinancieresUseCase;
    private final GetCompteCourantUseCase getCompteCourantUseCase;
    private final GetArreteUseCase getArreteUseCase;
    private final GetArreteDecompteUseCase getArreteDecompteUseCase;
    private final InitierPaiementUseCase initierPaiementUseCase;
    private final GetStatutPaiementUseCase getStatutPaiementUseCase;
    private final GetAllChauffeursUseCase getAllChauffeursUseCase;
    private final CreateIndisponibiliteUseCase createIndisponibiliteUseCase;
    private final GetAllIndisponibilitesUseCase getAllIndisponibilitesUseCase;
    private final TerminerIndisponibiliteUseCase terminerIndisponibiliteUseCase;
    private final IndisponibiliteRestMapper indisponibiliteMapper;
    private final ChauffeurRestMapper chauffeurMapper;
    private final RecetteRestMapper recetteMapper;
    private final CotisationRestMapper cotisationMapper;
    private final ContraventionRestMapper contraventionMapper;
    private final PenaliteRestMapper penaliteMapper;
    private final OperationFinanciereRestMapper operationMapper;

    @GetMapping("/profil")
    @Operation(summary = "Profil du chauffeur connecté")
    public ChauffeurResponse profil() {
        return chauffeurMapper.toResponse(currentChauffeur.resolveOrThrow());
    }

    @GetMapping("/recettes")
    @Operation(summary = "Recettes du chauffeur connecté")
    public List<LigneRecetteResponse> recettes(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return recetteMapper.toResponseList(getLignesRecetteUseCase.findByCriteres(
                LigneRecetteFiltres.builder()
                        .chauffeurId(chauffeurId).dateDebut(dateDebut).dateFin(dateFin)
                        .build()));
    }

    @GetMapping("/cotisations")
    @Operation(summary = "Cotisations du chauffeur connecté")
    public List<LigneCotisationResponse> cotisations(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return cotisationMapper.toResponseList(getLignesCotisationUseCase.findByCriteres(
                LigneCotisationFiltres.builder()
                        .chauffeurId(chauffeurId).dateDebut(dateDebut).dateFin(dateFin)
                        .build()));
    }

    @GetMapping("/contraventions")
    @Operation(summary = "Contraventions du chauffeur connecté")
    public List<ContraventionResponse> contraventions() {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return contraventionMapper.toResponseList(
                getAllContraventionsUseCase.execute(chauffeurId, null));
    }

    @GetMapping("/penalites")
    @Operation(summary = "Pénalités (amendes) du chauffeur connecté")
    public List<LignePenaliteResponse> penalites(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return penaliteMapper.toResponseList(getLignesPenaliteUseCase.findByCriteres(
                LignePenaliteFiltres.builder()
                        .chauffeurId(chauffeurId).dateDebut(dateDebut).dateFin(dateFin)
                        .build()));
    }

    @GetMapping("/operations")
    @Operation(summary = "Opérations financières liées au chauffeur ou à son véhicule")
    public List<OperationFinanciereResponse> operations() {
        Chauffeur chauffeur = currentChauffeur.resolveOrThrow();
        Long chauffeurId = chauffeur.getId();
        Long vehiculeId = (chauffeur.getVehicule() != null) ? chauffeur.getVehicule().getId() : null;

        // Opérations rattachées au chauffeur…
        List<OperationFinanciere> merged = new java.util.ArrayList<>(
                getAllOperationsFinancieresUseCase.execute(new OperationFinanciereFiltres(
                        null, null, null, null, null, null, null, chauffeurId, null)));
        java.util.Set<Long> ids = merged.stream()
                .map(OperationFinanciere::getId).collect(java.util.stream.Collectors.toSet());

        // …fusionnées avec celles de son véhicule (sans doublon).
        if (vehiculeId != null) {
            for (OperationFinanciere op : getAllOperationsFinancieresUseCase.execute(
                    new OperationFinanciereFiltres(
                            null, null, null, null, null, null, vehiculeId, null, null))) {
                if (ids.add(op.getId())) {
                    merged.add(op);
                }
            }
        }
        merged.sort(java.util.Comparator.comparing(
                OperationFinanciere::getDateOperation,
                java.util.Comparator.nullsLast(java.util.Comparator.naturalOrder())).reversed());
        return operationMapper.toResponseList(merged);
    }

    @GetMapping("/solde")
    @Operation(summary = "Soldes chauffeur et véhicule")
    public SoldeResponse solde() {
        Chauffeur chauffeur = currentChauffeur.resolveOrThrow();
        CompteCourantResponse soldeChauffeur = getCompteCourantUseCase.lister(PerimetreArrete.CHAUFFEUR).stream()
                .filter(c -> chauffeur.getId().equals(c.getTiersId()))
                .findFirst().map(ArreteCompteController::toCompteCourant).orElse(null);

        CompteCourantResponse soldeVehicule = null;
        if (chauffeur.getVehicule() != null && chauffeur.getVehicule().getId() != null) {
            Long vehiculeId = chauffeur.getVehicule().getId();
            soldeVehicule = getCompteCourantUseCase.lister(PerimetreArrete.VEHICULE).stream()
                    .filter(c -> vehiculeId.equals(c.getTiersId()))
                    .findFirst().map(ArreteCompteController::toCompteCourant).orElse(null);
        }
        return new SoldeResponse(soldeChauffeur, soldeVehicule);
    }

    // ── Paiement Mobile Money (V2) ─────────────────────────────────────────

    @PostMapping("/paiements")
    @Operation(summary = "Initier un paiement Mobile Money d'une recette ou cotisation")
    public PaiementResponse initierPaiement(@Valid @RequestBody PaiementRequest request) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return PaiementResponse.from(initierPaiementUseCase.executer(
                chauffeurId, request.typeCible(), request.cibleId(),
                request.canal(), request.telephone()));
    }

    @GetMapping("/paiements")
    @Operation(summary = "Historique des paiements du chauffeur connecté")
    public List<PaiementResponse> paiements() {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return getStatutPaiementUseCase.historique(chauffeurId).stream()
                .map(PaiementResponse::from)
                .toList();
    }

    @GetMapping("/paiements/{reference}")
    @Operation(summary = "Statut d'un paiement (rafraîchi auprès de l'agrégateur si en attente)")
    public PaiementResponse statutPaiement(@PathVariable String reference) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return PaiementResponse.from(getStatutPaiementUseCase.executer(chauffeurId, reference));
    }

    // ── Indisponibilités (déclaration par le chauffeur) ────────────────────

    @GetMapping("/remplacants")
    @Operation(summary = "Chauffeurs sélectionnables comme remplaçant")
    public List<RemplacantResponse> remplacants() {
        Long moi = currentChauffeur.resolveOrThrow().getId();
        return getAllChauffeursUseCase.execute().stream()
                .filter(c -> c.getStatut() == ChauffeurStatus.ACTIF)
                .filter(c -> !c.getId().equals(moi))
                .map(c -> new RemplacantResponse(c.getId(), c.getFullName(), c.getTelephone()))
                .toList();
    }

    @GetMapping("/indisponibilites")
    @Operation(summary = "Indisponibilités du chauffeur connecté")
    public List<IndisponibiliteResponse> indisponibilites() {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return indisponibiliteMapper.toResponseList(
                getAllIndisponibilitesUseCase.execute(chauffeurId));
    }

    @PostMapping("/indisponibilites")
    @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    @Operation(summary = "Déclarer une indisponibilité (le titulaire = chauffeur connecté)")
    public IndisponibiliteResponse declarerIndisponibilite(
            @Valid @RequestBody IndisponibiliteSelfRequest request) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        Indisponibilite indispo = Indisponibilite.builder()
                .chauffeur(Chauffeur.builder().id(chauffeurId).build())
                .chauffeurRemplacant(
                        Chauffeur.builder().id(request.chauffeurRemplacantId()).build())
                .dateDebut(request.dateDebut())
                .dateFin(request.dateFin())
                .motif(request.motif())
                .commentaire(request.commentaire())
                .build();
        return indisponibiliteMapper.toResponse(
                createIndisponibiliteUseCase.execute(indispo));
    }

    @PostMapping("/indisponibilites/{id}/terminer")
    @Operation(summary = "Terminer une de ses indisponibilités")
    public IndisponibiliteResponse terminerIndisponibilite(@PathVariable Long id) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        boolean sienne = getAllIndisponibilitesUseCase.execute(chauffeurId).stream()
                .anyMatch(i -> id.equals(i.getId()));
        if (!sienne) {
            throw new ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND,
                    "Indisponibilité introuvable : " + id);
        }
        return indisponibiliteMapper.toResponse(terminerIndisponibiliteUseCase.execute(id));
    }

    @PostMapping("/mot-de-passe")
    @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
    @Operation(summary = "Définir/changer son mot de passe",
            description = "Active la connexion par mot de passe pour le chauffeur connecté")
    public void definirMotDePasse(@Valid @RequestBody SetPasswordDto request) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        setChauffeurPasswordUseCase.execute(chauffeurId, request.motDePasse());
    }

    @GetMapping("/arretes")
    @Operation(summary = "Arrêtés de compte du chauffeur connecté")
    public List<ArreteResponse> arretes() {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        return getArreteUseCase.parBeneficiaire(chauffeurId).stream()
                .map(ArreteCompteController::toArrete)
                .toList();
    }

    @GetMapping("/arretes/{id}/pdf")
    @Operation(summary = "Décompte PDF d'un arrêté du chauffeur connecté")
    public ResponseEntity<byte[]> arretePdf(@PathVariable Long id) {
        Long chauffeurId = currentChauffeur.resolveOrThrow().getId();
        verifierAppartenance(chauffeurId, id);
        byte[] pdf = getArreteDecompteUseCase.executer(id);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=decompte_arrete_" + id + ".pdf")
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdf);
    }

    /** Refuse l'accès si l'arrêté demandé n'appartient pas au chauffeur courant. */
    private void verifierAppartenance(Long chauffeurId, Long arreteId) {
        boolean autorise = getArreteUseCase.parBeneficiaire(chauffeurId).stream()
                .anyMatch(a -> arreteId.equals(a.getId()));
        if (!autorise) {
            throw new ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND,
                    "Arrêté introuvable : " + arreteId);
        }
    }
}
