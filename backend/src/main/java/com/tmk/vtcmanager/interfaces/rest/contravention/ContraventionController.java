package com.tmk.vtcmanager.interfaces.rest.contravention;

import com.tmk.vtcmanager.application.domain.contravention.ApercuImportContraventions;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ResultatImportContraventions;
import com.tmk.vtcmanager.application.usecases.contravention.ConfirmerImportContraventionsUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.CreateContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.DeleteContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.GetAllContraventionsUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.GetContraventionByIdUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.ImporterContraventionsUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.PayContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.ReverseContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.UpdateContraventionUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.ConfirmerImportRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.ContraventionRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.PaymentRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ApercuImportResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ContraventionResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ResultatImportResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.mapper.ContraventionRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/contraventions")
@RequiredArgsConstructor
public class ContraventionController {

    private final CreateContraventionUseCase createContraventionUseCase;
    private final UpdateContraventionUseCase updateContraventionUseCase;
    private final DeleteContraventionUseCase deleteContraventionUseCase;
    private final GetContraventionByIdUseCase getContraventionByIdUseCase;
    private final GetAllContraventionsUseCase getAllContraventionsUseCase;
    private final PayContraventionUseCase payContraventionUseCase;
    private final ReverseContraventionUseCase reverseContraventionUseCase;
    private final ImporterContraventionsUseCase importerContraventionsUseCase;
    private final ConfirmerImportContraventionsUseCase confirmerImportContraventionsUseCase;
    private final ContraventionRestMapper mapper;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ContraventionResponse create(@Valid @RequestBody ContraventionRequest request) {
        Contravention created = createContraventionUseCase.execute(mapper.toDomain(request));
        return mapper.toResponse(created);
    }

    @GetMapping
    public List<ContraventionResponse> findAll(
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) Long vehiculeId) {
        return mapper.toResponseList(getAllContraventionsUseCase.execute(chauffeurId, vehiculeId));
    }

    @GetMapping("/page")
    public PageResponse<ContraventionResponse> findPage(
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var result = getAllContraventionsUseCase
                .executePage(chauffeurId, vehiculeId, page, size)
                .map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public ContraventionResponse findById(@PathVariable Long id) {
        return mapper.toResponse(getContraventionByIdUseCase.execute(id));
    }

    @PutMapping("/{id}")
    public ContraventionResponse update(@PathVariable Long id, @Valid @RequestBody ContraventionRequest request) {
        Contravention updated = updateContraventionUseCase.execute(id, mapper.toDomain(request));
        return mapper.toResponse(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteContraventionUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/payments")
    public ContraventionResponse pay(@PathVariable Long id, @Valid @RequestBody PaymentRequest request) {
        return mapper.toResponse(payContraventionUseCase.execute(id, request.montantPaye(), request.modePaiement()));
    }

    @PostMapping("/{id}/reverse")
    public ContraventionResponse reverse(@PathVariable Long id) {
        return mapper.toResponse(reverseContraventionUseCase.execute(id));
    }

    // ── Import PDF (Mode 1) ─────────────────────────────────────────────────

    /** Prévisualise un relevé PDF : extraction, résolution véhicule/chauffeur, doublons. Rien n'est persisté. */
    @PostMapping(value = "/importer", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApercuImportResponse importer(@RequestPart("fichier") MultipartFile fichier) throws IOException {
        ApercuImportContraventions apercu = importerContraventionsUseCase.previsualiser(
                fichier.getInputStream(), fichier.getOriginalFilename(), fichier.getContentType());
        return mapper.toApercuResponse(apercu);
    }

    /** Confirme l'import : persiste les contraventions révisées par l'exploitant. */
    @PostMapping("/confirmer")
    @ResponseStatus(HttpStatus.CREATED)
    public ResultatImportResponse confirmer(@Valid @RequestBody ConfirmerImportRequest request) {
        ResultatImportContraventions resultat = confirmerImportContraventionsUseCase.confirmer(
                mapper.toImportDomainList(request.contraventions()));
        return mapper.toResultatResponse(resultat);
    }
}
