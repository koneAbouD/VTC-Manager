package com.tmk.vtcmanager.interfaces.rest.partenaire;

import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.partenaire.TypePartenaire;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.usecases.partenaire.AnnulerFactureUseCase;
import com.tmk.vtcmanager.application.usecases.partenaire.EnregistrerFactureUseCase;
import com.tmk.vtcmanager.application.usecases.partenaire.GestionPartenaireUseCase;
import com.tmk.vtcmanager.application.usecases.partenaire.GetFacturesUseCase;
import com.tmk.vtcmanager.application.usecases.partenaire.ReglerFactureUseCase;
import com.tmk.vtcmanager.interfaces.rest.partenaire.dto.request.FacturePartenaireRequest;
import com.tmk.vtcmanager.interfaces.rest.partenaire.dto.request.PartenaireRequest;
import com.tmk.vtcmanager.interfaces.rest.partenaire.dto.request.ReglementFactureRequest;
import com.tmk.vtcmanager.interfaces.rest.partenaire.dto.response.FacturePartenaireResponse;
import com.tmk.vtcmanager.interfaces.rest.partenaire.dto.response.PartenaireResponse;
import com.tmk.vtcmanager.interfaces.rest.partenaire.dto.response.ReglementResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.AnnulationRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

/**
 * Partenaires et factures à payer.
 *
 * <p>La facture porte la charge à sa date ; le règlement ne fait que sortir
 * l'argent et réduire la dette.
 */
@RestController
@RequestMapping("/api/partenaires")
@RequiredArgsConstructor
public class PartenaireController {

    private final GestionPartenaireUseCase gestionPartenaireUseCase;
    private final EnregistrerFactureUseCase enregistrerFactureUseCase;
    private final ReglerFactureUseCase reglerFactureUseCase;
    private final AnnulerFactureUseCase annulerFactureUseCase;
    private final GetFacturesUseCase getFacturesUseCase;

    // ── Référentiel partenaires ─────────────────────────────────────────

    @GetMapping
    public List<PartenaireResponse> lister(
            @RequestParam(defaultValue = "true") boolean actifsSeulement) {
        return gestionPartenaireUseCase.lister(actifsSeulement).stream()
                .map(this::toResponse).toList();
    }

    @GetMapping("/{id}")
    public PartenaireResponse parId(@PathVariable Long id) {
        return toResponse(gestionPartenaireUseCase.parId(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PartenaireResponse creer(@Valid @RequestBody PartenaireRequest request) {
        return toResponse(gestionPartenaireUseCase.creer(toDomain(request)));
    }

    @PutMapping("/{id}")
    public PartenaireResponse modifier(@PathVariable Long id,
                                        @Valid @RequestBody PartenaireRequest request) {
        return toResponse(gestionPartenaireUseCase.modifier(id, toDomain(request)));
    }

    /** Un partenaire ne se supprime pas : il a un historique comptable. */
    @PatchMapping("/{id}/activation")
    public PartenaireResponse changerActivation(@PathVariable Long id,
                                                 @RequestParam boolean actif) {
        return toResponse(gestionPartenaireUseCase.changerActivation(id, actif));
    }

    // ── Factures ─────────────────────────────────────────────────────────

    @PostMapping("/factures")
    @ResponseStatus(HttpStatus.CREATED)
    public FacturePartenaireResponse enregistrerFacture(
            @Valid @RequestBody FacturePartenaireRequest request) {
        return toResponse(enregistrerFactureUseCase.executer(toDomain(request)));
    }

    @GetMapping("/factures/{id}")
    public FacturePartenaireResponse facture(@PathVariable Long id) {
        return toResponse(getFacturesUseCase.parId(id));
    }

    /** Historique des règlements : ce qui explique le restant dû. */
    @GetMapping("/factures/{id}/reglements")
    public List<ReglementResponse> reglements(@PathVariable Long id) {
        return getFacturesUseCase.reglements(id).stream()
                .map(o -> new ReglementResponse(o.getId(), o.getReference(),
                        o.getDateOperation(), o.getMontant(),
                        o.getModePaiement() != null ? o.getModePaiement().name() : null,
                        o.getCommentaire(), o.estExtournee()))
                .toList();
    }

    /** Factures reçues sur un mois — la charge de la période. */
    @GetMapping("/factures")
    public List<FacturePartenaireResponse> facturesDuMois(@RequestParam int annee,
                                                           @RequestParam int mois) {
        return getFacturesUseCase.parPeriode(annee, mois).stream()
                .map(this::toResponse).toList();
    }

    /** Échéancier : ce qui reste à payer, échéance la plus ancienne en tête. */
    @GetMapping("/factures/echeancier")
    public List<FacturePartenaireResponse> echeancier(
            @RequestParam(required = false) Long partenaireId) {
        return getFacturesUseCase.echeancier(partenaireId).stream()
                .map(this::toResponse).toList();
    }

    /** Dettes laissées par une intervention terminée sans être réglée. */
    @GetMapping("/factures/par-maintenance/{maintenanceId}")
    public List<FacturePartenaireResponse> facturesDeMaintenance(@PathVariable Long maintenanceId) {
        return getFacturesUseCase.parMaintenance(maintenanceId).stream()
                .map(this::toResponse).toList();
    }

    @GetMapping("/factures/en-retard")
    public List<FacturePartenaireResponse> enRetard() {
        return getFacturesUseCase.enRetard(LocalDate.now()).stream()
                .map(this::toResponse).toList();
    }

    @PostMapping("/factures/{id}/reglements")
    public FacturePartenaireResponse regler(@PathVariable Long id,
                                             @Valid @RequestBody ReglementFactureRequest request) {
        return toResponse(reglerFactureUseCase.executer(id, request.montant(),
                request.modePaiement(), request.compteTresorerieId(),
                request.datePaiement(), request.commentaire()));
    }

    @PatchMapping("/factures/{id}/annuler")
    public FacturePartenaireResponse annulerFacture(@PathVariable Long id,
                                                     @Valid @RequestBody AnnulationRequest request) {
        return toResponse(annulerFactureUseCase.executer(id, request.motif()));
    }

    // ── Conversions ──────────────────────────────────────────────────────

    private Partenaire toDomain(PartenaireRequest r) {
        return Partenaire.builder()
                .nom(r.nom())
                .type(TypePartenaire.builder().id(r.typeId()).build())
                .telephone(r.telephone())
                .email(r.email())
                .adresse(r.adresse())
                .numeroCompteContribuable(r.numeroCompteContribuable())
                .commentaire(r.commentaire())
                .build();
    }

    private FacturePartenaire toDomain(FacturePartenaireRequest r) {
        return FacturePartenaire.builder()
                .partenaire(Partenaire.builder().id(r.partenaireId()).build())
                .numeroPiece(r.numeroPiece())
                .categorie(r.categorieId() != null
                        ? CategorieOperation.builder().id(r.categorieId()).build() : null)
                .vehicule(r.vehiculeId() != null
                        ? Vehicule.builder().id(r.vehiculeId()).build() : null)
                .dateFacture(r.dateFacture())
                .dateEcheance(r.dateEcheance())
                .montant(r.montant())
                .description(r.description())
                .build();
    }

    private PartenaireResponse toResponse(Partenaire p) {
        return new PartenaireResponse(p.getId(), p.getNom(),
                p.getType() != null ? p.getType().getId() : null,
                p.getType() != null ? p.getType().getNom() : null,
                p.getTelephone(), p.getEmail(), p.getAdresse(),
                p.getNumeroCompteContribuable(), p.getCommentaire(), p.isActif());
    }

    private FacturePartenaireResponse toResponse(FacturePartenaire f) {
        return new FacturePartenaireResponse(
                f.getId(), f.getReference(),
                f.getPartenaire() != null ? f.getPartenaire().getId() : null,
                f.getPartenaire() != null ? f.getPartenaire().getNom() : null,
                f.getNumeroPiece(),
                f.getCategorie() != null ? f.getCategorie().getId() : null,
                f.getCategorie() != null ? f.getCategorie().getLibelle() : null,
                f.getVehicule() != null ? f.getVehicule().getId() : null,
                f.getVehicule() != null ? f.getVehicule().getImmatriculation() : null,
                f.getDateFacture(), f.getDateEcheance(), f.getMontant(), f.getMontantPaye(),
                f.restantDu(), f.getStatut(), f.estEnRetard(LocalDate.now()),
                f.getDescription(), f.getMotifAnnulation(), f.getMaintenanceId(),
                f.getLignes() == null ? List.of() : f.getLignes().stream()
                        .map(l -> new FacturePartenaireResponse.LigneDetteResponse(
                                l.libelle(), l.montant()))
                        .toList());
    }
}
