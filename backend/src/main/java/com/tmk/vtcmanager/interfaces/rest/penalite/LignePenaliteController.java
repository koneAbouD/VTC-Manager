package com.tmk.vtcmanager.interfaces.rest.penalite;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenaliteFiltres;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.usecases.penalite.AnnulerLignePenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.RestaurerLignePenaliteUseCase;
import com.tmk.vtcmanager.application.services.ModificationDateEncaissementService;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import com.tmk.vtcmanager.application.usecases.penalite.CreateEncaissementPenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.CreateLignePenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.DemarrerImmobilisationUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.ExecuterBuzzerUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.GenererLignesPenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.GetLignesPenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.LeverImmobilisationUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.ModifierDateEncaissementPenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.penalite.NotifierAvertissementUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.AnnulationRequest;
import com.tmk.vtcmanager.interfaces.rest.common.ModificationDateEncaissementRequest;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.request.EncaissementPenaliteRequest;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.request.LignePenaliteRequest;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.request.SignalerRetardRequest;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.response.EncaissementPenaliteResponse;
import com.tmk.vtcmanager.interfaces.rest.penalite.dto.response.LignePenaliteResponse;
import com.tmk.vtcmanager.interfaces.rest.penalite.mapper.PenaliteRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/penalites/lignes")
@RequiredArgsConstructor
public class LignePenaliteController {

    private final GetLignesPenaliteUseCase getLignesUseCase;
    private final CreateLignePenaliteUseCase createLigneUseCase;
    private final CreateEncaissementPenaliteUseCase createEncaissementUseCase;
    private final AnnulerLignePenaliteUseCase annulerUseCase;
    private final RestaurerLignePenaliteUseCase restaurerUseCase;
    private final ModifierDateEncaissementPenaliteUseCase modifierDateEncaissementUseCase;
    private final VerrouArreteService verrouArreteService;
    private final ModificationDateEncaissementService modificationDateEncaissementService;
    private final ExecuterBuzzerUseCase executerBuzzerUseCase;
    private final NotifierAvertissementUseCase notifierUseCase;
    private final DemarrerImmobilisationUseCase demarrerUseCase;
    private final LeverImmobilisationUseCase leverUseCase;
    private final GenererLignesPenaliteUseCase genererUseCase;
    private final PenaliteRestMapper mapper;

    @GetMapping
    public List<LignePenaliteResponse> getLignes(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) TypeSanction typeSanction,
            @RequestParam(required = false) StatutLignePenalite statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        return mapper.toResponseList(getLignesUseCase.findByCriteres(
                LignePenaliteFiltres.builder()
                        .vehiculeId(vehiculeId).chauffeurId(chauffeurId)
                        .typeSanction(typeSanction).statut(statut)
                        .dateDebut(dateDebut).dateFin(dateFin)
                        .build()));
    }

    @GetMapping("/page")
    public PageResponse<LignePenaliteResponse> getLignesPage(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) TypeSanction typeSanction,
            @RequestParam(required = false) StatutLignePenalite statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin,
            @RequestParam(required = false) String recherche,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var result = getLignesUseCase.findPageByCriteres(
                LignePenaliteFiltres.builder()
                        .vehiculeId(vehiculeId).chauffeurId(chauffeurId)
                        .typeSanction(typeSanction).statut(statut)
                        .dateDebut(dateDebut).dateFin(dateFin)
                        .recherche(recherche)
                        .build(),
                page, size).map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public LignePenaliteResponse getLigneById(@PathVariable Long id) {
        return mapper.toResponse(enrichir(getLignesUseCase.findById(id)));
    }

    /**
     * Ce que la fiche a le droit de proposer, en un seul endroit : chaque action
     * dit au client si elle est encore ouverte, plutôt que de le laisser tenter
     * puis échouer.
     */
    private LignePenalite enrichir(LignePenalite ligne) {
        // « Restaurer » a-t-il encore un sens : un arrêté — période close,
        // caisse comptée — peut l'avoir fermée depuis.
        ligne.setRestaurable(verrouArreteService.estRestaurable(
                ligne.getDateFaute() != null ? ligne.getDateFaute() : ligne.getDateGeneration()));
        // Et, versement par versement, si sa date reste corrigeable.
        modificationDateEncaissementService.marquerVersements(ligne);
        return ligne;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public LignePenaliteResponse createLigne(@Valid @RequestBody LignePenaliteRequest request) {
        return mapper.toResponse(createLigneUseCase.executer(mapper.toDomain(request)));
    }

    @PostMapping("/signaler-retard")
    @ResponseStatus(HttpStatus.CREATED)
    public LignePenaliteResponse signalerRetard(@Valid @RequestBody SignalerRetardRequest request) {
        return mapper.toResponse(createLigneUseCase.signalerRetard(
                request.vehiculeId(), request.chauffeurId(),
                request.dateFaute(), request.commentaire()));
    }

    @PostMapping("/{id}/encaissements")
    @ResponseStatus(HttpStatus.CREATED)
    public EncaissementPenaliteResponse createEncaissement(
            @PathVariable Long id,
            @Valid @RequestBody EncaissementPenaliteRequest request) {
        return mapper.toEncaissementResponse(
                createEncaissementUseCase.executer(id, mapper.toDomain(request)));
    }

    @GetMapping("/{id}/encaissements")
    public List<EncaissementPenaliteResponse> getEncaissements(@PathVariable Long id) {
        return mapper.toEncaissementResponseList(getLignesUseCase.findById(id).getEncaissements());
    }

    /**
     * Corrige le jour d'un versement d'amende déjà enregistré : l'encaissement
     * et l'écriture qu'il a produite au journal changent de date ensemble.
     * Aucun montant ne bouge — le solde de trésorerie à date, le résultat du
     * mois et l'ancienneté de la créance suivent d'eux-mêmes. Refusé si un
     * arrêté a consigné la pénalité, si la période est close, si la caisse a
     * été comptée à l'une des deux dates, ou si le versement a été extourné.
     */
    @PatchMapping("/{id}/encaissements/{encaissementId}/date")
    public LignePenaliteResponse modifierDateEncaissement(
            @PathVariable Long id,
            @PathVariable Long encaissementId,
            @Valid @RequestBody ModificationDateEncaissementRequest request) {
        return mapper.toResponse(enrichir(modifierDateEncaissementUseCase.executer(
                id, encaissementId, request.dateEncaissement())));
    }

    @PatchMapping("/{id}/executer")
    public LignePenaliteResponse executer(@PathVariable Long id) {
        return mapper.toResponse(executerBuzzerUseCase.executer(id));
    }

    @PatchMapping("/{id}/notifier")
    public LignePenaliteResponse notifier(@PathVariable Long id) {
        return mapper.toResponse(notifierUseCase.executer(id));
    }

    @PatchMapping("/{id}/demarrer")
    public LignePenaliteResponse demarrer(@PathVariable Long id) {
        return mapper.toResponse(demarrerUseCase.executer(id));
    }

    @PatchMapping("/{id}/lever")
    public LignePenaliteResponse lever(@PathVariable Long id) {
        return mapper.toResponse(leverUseCase.executer(id));
    }

    /**
     * Remet une pénalité annulée en circulation : une amende retrouve le statut
     * que dictent ses versements, les autres sanctions repartent en attente
     * d'exécution. Refusé si la période est clôturée.
     */
    @PatchMapping("/{id}/restaurer")
    public LignePenaliteResponse restaurer(@PathVariable Long id) {
        return mapper.toResponse(restaurerUseCase.executer(id));
    }

    @PatchMapping("/{id}/annuler")
    public LignePenaliteResponse annuler(@PathVariable Long id,
                                         @Valid @RequestBody AnnulationRequest request) {
        return mapper.toResponse(annulerUseCase.executer(id, request.motif()));
    }

    @PostMapping("/generer")
    @ResponseStatus(HttpStatus.CREATED)
    public List<LignePenaliteResponse> generer(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return mapper.toResponseList(genererUseCase.executerPourRecettesNonVersees(
                date != null ? date : LocalDate.now().minusDays(1)));
    }
}
