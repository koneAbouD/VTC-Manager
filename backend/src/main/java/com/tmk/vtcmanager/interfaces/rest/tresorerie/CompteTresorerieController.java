package com.tmk.vtcmanager.interfaces.rest.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TransfertTresorerie;
import com.tmk.vtcmanager.application.usecases.finance.GetMontantAReverserEtatUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.CloturerCaisseUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.CreateCompteTresorerieUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.CreateTransfertUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.GetCloturesCaisseUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.GetComptesTresorerieUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.GetTransfertsUseCase;
import com.tmk.vtcmanager.application.usecases.tresorerie.UpdateCompteTresorerieUseCase;
import com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request.ClotureCaisseRequest;
import com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request.CompteTresorerieRequest;
import com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request.CompteTresorerieUpdateRequest;
import com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request.TransfertRequest;
import com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response.ClotureCaisseResponse;
import com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response.CompteTresorerieResponse;
import com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response.TransfertResponse;
import com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response.TresorerieSummaryResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api/comptes-tresorerie")
@RequiredArgsConstructor
public class CompteTresorerieController {

    private final GetComptesTresorerieUseCase getComptesUseCase;
    private final CreateCompteTresorerieUseCase createUseCase;
    private final UpdateCompteTresorerieUseCase updateUseCase;
    private final GetMontantAReverserEtatUseCase getMontantAReverserEtatUseCase;
    private final CreateTransfertUseCase createTransfertUseCase;
    private final GetTransfertsUseCase getTransfertsUseCase;
    private final CloturerCaisseUseCase cloturerCaisseUseCase;
    private final GetCloturesCaisseUseCase getCloturesCaisseUseCase;

    @GetMapping
    public TresorerieSummaryResponse findAll(
            @RequestParam(defaultValue = "true") boolean actifsSeulement) {
        List<CompteAvecSolde> comptes = getComptesUseCase.executer(actifsSeulement);

        List<CompteTresorerieResponse> responses = comptes.stream()
                .map(this::toResponse)
                .toList();
        BigDecimal total = comptes.stream()
                .map(CompteAvecSolde::getSolde)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new TresorerieSummaryResponse(responses, total,
                getMontantAReverserEtatUseCase.executer());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CompteTresorerieResponse create(@Valid @RequestBody CompteTresorerieRequest request) {
        CompteTresorerie compte = CompteTresorerie.builder()
                .code(request.code())
                .libelle(request.libelle())
                .type(request.type())
                .operateur(request.operateur())
                .soldeInitial(request.soldeInitial())
                .parDefaut(request.parDefaut())
                .build();
        CompteTresorerie saved = createUseCase.executer(compte);
        return toResponse(new CompteAvecSolde(saved, saved.getSoldeInitial()));
    }

    @PutMapping("/{id}")
    public CompteTresorerieResponse update(@PathVariable Long id,
                                           @Valid @RequestBody CompteTresorerieUpdateRequest request) {
        CompteTresorerie modifications = CompteTresorerie.builder()
                .libelle(request.libelle())
                .operateur(request.operateur())
                .soldeInitial(request.soldeInitial())
                .parDefaut(request.parDefaut())
                .actif(request.actif())
                .build();
        CompteTresorerie saved = updateUseCase.executer(id, modifications);
        return toResponse(new CompteAvecSolde(saved, null));
    }

    // ── Transferts inter-comptes ─────────────────────────────────────────

    @PostMapping("/transferts")
    @ResponseStatus(HttpStatus.CREATED)
    public TransfertResponse createTransfert(@Valid @RequestBody TransfertRequest request) {
        TransfertTresorerie transfert = TransfertTresorerie.builder()
                .compteSourceId(request.compteSourceId())
                .compteDestinationId(request.compteDestinationId())
                .montant(request.montant())
                .dateTransfert(request.dateTransfert())
                .commentaire(request.commentaire())
                .build();
        return toResponse(createTransfertUseCase.executer(transfert));
    }

    @GetMapping("/transferts")
    public List<TransfertResponse> getTransferts() {
        return getTransfertsUseCase.executer().stream().map(this::toResponse).toList();
    }

    // ── Clôture de caisse ────────────────────────────────────────────────

    @PostMapping("/{id}/clotures")
    @ResponseStatus(HttpStatus.CREATED)
    public ClotureCaisseResponse cloturerCaisse(@PathVariable Long id,
                                                @Valid @RequestBody ClotureCaisseRequest request) {
        return toResponse(cloturerCaisseUseCase.executer(id, request.soldeCompte(), request.motifEcart()));
    }

    @GetMapping("/{id}/clotures")
    public List<ClotureCaisseResponse> getClotures(@PathVariable Long id) {
        return getCloturesCaisseUseCase.executer(id).stream().map(this::toResponse).toList();
    }

    private TransfertResponse toResponse(TransfertTresorerie t) {
        return new TransfertResponse(t.getId(), t.getCompteSourceId(), t.getCompteDestinationId(),
                t.getMontant(), t.getDateTransfert(), t.getCommentaire());
    }

    private ClotureCaisseResponse toResponse(ClotureCaisse c) {
        return new ClotureCaisseResponse(c.getId(), c.getCompteId(), c.getDateCloture(),
                c.getSoldeTheorique(), c.getSoldeCompte(), c.getEcart(), c.getMotifEcart(),
                c.getOperationId());
    }

    private CompteTresorerieResponse toResponse(CompteAvecSolde avecSolde) {
        CompteTresorerie c = avecSolde.getCompte();
        return new CompteTresorerieResponse(c.getId(), c.getCode(), c.getLibelle(),
                c.getType(), c.getOperateur(), c.getSoldeInitial(),
                c.isParDefaut(), c.isActif(), avecSolde.getSolde());
    }
}
