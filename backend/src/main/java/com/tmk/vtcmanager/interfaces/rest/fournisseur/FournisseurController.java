package com.tmk.vtcmanager.interfaces.rest.fournisseur;

import com.tmk.vtcmanager.application.domain.fournisseur.FactureFournisseur;
import com.tmk.vtcmanager.application.domain.fournisseur.Fournisseur;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.usecases.fournisseur.AnnulerFactureUseCase;
import com.tmk.vtcmanager.application.usecases.fournisseur.EnregistrerFactureUseCase;
import com.tmk.vtcmanager.application.usecases.fournisseur.GestionFournisseurUseCase;
import com.tmk.vtcmanager.application.usecases.fournisseur.GetFacturesUseCase;
import com.tmk.vtcmanager.application.usecases.fournisseur.ReglerFactureUseCase;
import com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.request.FactureFournisseurRequest;
import com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.request.FournisseurRequest;
import com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.request.ReglementFactureRequest;
import com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.response.FactureFournisseurResponse;
import com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.response.FournisseurResponse;
import com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.response.ReglementResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.AnnulationRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

/**
 * Fournisseurs et factures à payer.
 *
 * <p>La facture porte la charge à sa date ; le règlement ne fait que sortir
 * l'argent et réduire la dette.
 */
@RestController
@RequestMapping("/api/fournisseurs")
@RequiredArgsConstructor
public class FournisseurController {

    private final GestionFournisseurUseCase gestionFournisseurUseCase;
    private final EnregistrerFactureUseCase enregistrerFactureUseCase;
    private final ReglerFactureUseCase reglerFactureUseCase;
    private final AnnulerFactureUseCase annulerFactureUseCase;
    private final GetFacturesUseCase getFacturesUseCase;

    // ── Référentiel fournisseurs ─────────────────────────────────────────

    @GetMapping
    public List<FournisseurResponse> lister(
            @RequestParam(defaultValue = "true") boolean actifsSeulement) {
        return gestionFournisseurUseCase.lister(actifsSeulement).stream()
                .map(this::toResponse).toList();
    }

    @GetMapping("/{id}")
    public FournisseurResponse parId(@PathVariable Long id) {
        return toResponse(gestionFournisseurUseCase.parId(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public FournisseurResponse creer(@Valid @RequestBody FournisseurRequest request) {
        return toResponse(gestionFournisseurUseCase.creer(toDomain(request)));
    }

    @PutMapping("/{id}")
    public FournisseurResponse modifier(@PathVariable Long id,
                                        @Valid @RequestBody FournisseurRequest request) {
        return toResponse(gestionFournisseurUseCase.modifier(id, toDomain(request)));
    }

    /** Un fournisseur ne se supprime pas : il a un historique comptable. */
    @PatchMapping("/{id}/activation")
    public FournisseurResponse changerActivation(@PathVariable Long id,
                                                 @RequestParam boolean actif) {
        return toResponse(gestionFournisseurUseCase.changerActivation(id, actif));
    }

    // ── Factures ─────────────────────────────────────────────────────────

    @PostMapping("/factures")
    @ResponseStatus(HttpStatus.CREATED)
    public FactureFournisseurResponse enregistrerFacture(
            @Valid @RequestBody FactureFournisseurRequest request) {
        return toResponse(enregistrerFactureUseCase.executer(toDomain(request)));
    }

    @GetMapping("/factures/{id}")
    public FactureFournisseurResponse facture(@PathVariable Long id) {
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
    public List<FactureFournisseurResponse> facturesDuMois(@RequestParam int annee,
                                                           @RequestParam int mois) {
        return getFacturesUseCase.parPeriode(annee, mois).stream()
                .map(this::toResponse).toList();
    }

    /** Échéancier : ce qui reste à payer, échéance la plus ancienne en tête. */
    @GetMapping("/factures/echeancier")
    public List<FactureFournisseurResponse> echeancier(
            @RequestParam(required = false) Long fournisseurId) {
        return getFacturesUseCase.echeancier(fournisseurId).stream()
                .map(this::toResponse).toList();
    }

    @GetMapping("/factures/en-retard")
    public List<FactureFournisseurResponse> enRetard() {
        return getFacturesUseCase.enRetard(LocalDate.now()).stream()
                .map(this::toResponse).toList();
    }

    @PostMapping("/factures/{id}/reglements")
    public FactureFournisseurResponse regler(@PathVariable Long id,
                                             @Valid @RequestBody ReglementFactureRequest request) {
        return toResponse(reglerFactureUseCase.executer(id, request.montant(),
                request.modePaiement(), request.compteTresorerieId(),
                request.datePaiement(), request.commentaire()));
    }

    @PatchMapping("/factures/{id}/annuler")
    public FactureFournisseurResponse annulerFacture(@PathVariable Long id,
                                                     @Valid @RequestBody AnnulationRequest request) {
        return toResponse(annulerFactureUseCase.executer(id, request.motif()));
    }

    // ── Conversions ──────────────────────────────────────────────────────

    private Fournisseur toDomain(FournisseurRequest r) {
        return Fournisseur.builder()
                .nom(r.nom())
                .type(r.type())
                .telephone(r.telephone())
                .email(r.email())
                .adresse(r.adresse())
                .numeroCompteContribuable(r.numeroCompteContribuable())
                .commentaire(r.commentaire())
                .build();
    }

    private FactureFournisseur toDomain(FactureFournisseurRequest r) {
        return FactureFournisseur.builder()
                .fournisseur(Fournisseur.builder().id(r.fournisseurId()).build())
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

    private FournisseurResponse toResponse(Fournisseur f) {
        return new FournisseurResponse(f.getId(), f.getNom(), f.getType(), f.getTelephone(),
                f.getEmail(), f.getAdresse(), f.getNumeroCompteContribuable(),
                f.getCommentaire(), f.isActif());
    }

    private FactureFournisseurResponse toResponse(FactureFournisseur f) {
        return new FactureFournisseurResponse(
                f.getId(), f.getReference(),
                f.getFournisseur() != null ? f.getFournisseur().getId() : null,
                f.getFournisseur() != null ? f.getFournisseur().getNom() : null,
                f.getNumeroPiece(),
                f.getCategorie() != null ? f.getCategorie().getId() : null,
                f.getCategorie() != null ? f.getCategorie().getLibelle() : null,
                f.getVehicule() != null ? f.getVehicule().getId() : null,
                f.getVehicule() != null ? f.getVehicule().getImmatriculation() : null,
                f.getDateFacture(), f.getDateEcheance(), f.getMontant(), f.getMontantPaye(),
                f.restantDu(), f.getStatut(), f.estEnRetard(LocalDate.now()),
                f.getDescription(), f.getMotifAnnulation());
    }
}
