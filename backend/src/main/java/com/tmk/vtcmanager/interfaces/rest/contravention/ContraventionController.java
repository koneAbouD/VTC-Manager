package com.tmk.vtcmanager.interfaces.rest.contravention;

import com.tmk.vtcmanager.application.domain.contravention.ApercuImportContraventions;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ResultatImportContraventions;
import com.tmk.vtcmanager.application.domain.contravention.reversement.ApercuReversementQuittance;
import com.tmk.vtcmanager.application.domain.contravention.reversement.ResultatReversementQuittance;
import com.tmk.vtcmanager.application.usecases.contravention.AnnulerContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.RestaurerContraventionUseCase;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import com.tmk.vtcmanager.application.usecases.contravention.ConfirmerImportContraventionsUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.ConfirmerReversementQuittanceUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.PreviewReversementQuittanceUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.CreateContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.DeleteContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.GetAllContraventionsUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.GetContraventionByIdUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.ImporterContraventionsUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.PayContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.ReverseContraventionUseCase;
import com.tmk.vtcmanager.application.usecases.contravention.UpdateContraventionUseCase;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import com.tmk.vtcmanager.interfaces.rest.common.AnnulationRequest;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.ConfirmerImportRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.ConfirmerReversementRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.ContraventionRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.request.PaymentRequest;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ApercuImportResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ApercuReversementResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ContraventionResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ResultatImportResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.dto.response.ResultatReversementResponse;
import com.tmk.vtcmanager.interfaces.rest.contravention.mapper.ContraventionRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.InputStreamResource;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/contraventions")
@RequiredArgsConstructor
public class ContraventionController {

    private final CreateContraventionUseCase createContraventionUseCase;
    private final UpdateContraventionUseCase updateContraventionUseCase;
    private final DeleteContraventionUseCase deleteContraventionUseCase;
    private final AnnulerContraventionUseCase annulerContraventionUseCase;
    private final RestaurerContraventionUseCase restaurerContraventionUseCase;
    private final VerrouArreteService verrouArreteService;
    private final GetContraventionByIdUseCase getContraventionByIdUseCase;
    private final GetAllContraventionsUseCase getAllContraventionsUseCase;
    private final PayContraventionUseCase payContraventionUseCase;
    private final ReverseContraventionUseCase reverseContraventionUseCase;
    private final ImporterContraventionsUseCase importerContraventionsUseCase;
    private final ConfirmerImportContraventionsUseCase confirmerImportContraventionsUseCase;
    private final PreviewReversementQuittanceUseCase previewReversementQuittanceUseCase;
    private final ConfirmerReversementQuittanceUseCase confirmerReversementQuittanceUseCase;
    private final FileStoragePort fileStoragePort;
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
        // Cette liste alimente le détail côté mobile : sans le marquage, la
        // contravention y arriverait sans son verrou et le bouton
        // « Restaurer » disparaîtrait à tort.
        var verrous = verrouArreteService.verrous();
        return getAllContraventionsUseCase.execute(chauffeurId, vehiculeId).stream()
                .map(c -> {
                    c.setRestaurable(verrous.autorise(c.getDateInfraction()));
                    return mapper.toResponse(c);
                })
                .toList();
    }

    @GetMapping("/page")
    public PageResponse<ContraventionResponse> findPage(
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin,
            @RequestParam(required = false) String recherche,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        // Les bornes des arrêtés sont lues une seule fois, puis appliquées en
        // mémoire : marquer une page ne doit pas coûter deux requêtes par ligne.
        var verrous = verrouArreteService.verrous();
        var result = getAllContraventionsUseCase
                .executePage(chauffeurId, vehiculeId, dateDebut, dateFin, recherche, page, size)
                .map(c -> {
                    c.setRestaurable(verrous.autorise(c.getDateInfraction()));
                    return mapper.toResponse(c);
                });
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public ContraventionResponse findById(@PathVariable Long id) {
        Contravention contravention = getContraventionByIdUseCase.execute(id);
        contravention.setRestaurable(
                verrouArreteService.estRestaurable(contravention.getDateInfraction()));
        return mapper.toResponse(contravention);
    }

    /**
     * Streame le document source archivé (relevé PDF importé) d'une
     * contravention. 404 si aucun document n'est rattaché.
     */
    @GetMapping("/{id:\\d+}/document")
    public ResponseEntity<InputStreamResource> document(@PathVariable Long id) {
        Contravention contravention = getContraventionByIdUseCase.execute(id);
        String objectName = contravention.getDocumentSourcePath();
        if (objectName == null || objectName.isBlank()) {
            return ResponseEntity.notFound().build();
        }
        InputStream stream = fileStoragePort.download(objectName);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"contravention-" + id + ".pdf\"")
                .body(new InputStreamResource(stream));
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

    /**
     * Annule une contravention saisie à tort : elle reste au registre, datée et
     * motivée, et cesse d'être due à compter de ce jour. Les états déjà arrêtés
     * continuent de la porter — elle y figurait bien.
     */
    @PatchMapping("/{id}/annuler")
    public ContraventionResponse annuler(@PathVariable Long id,
                                         @Valid @RequestBody AnnulationRequest request) {
        return mapper.toResponse(annulerContraventionUseCase.execute(id, request.motif()));
    }

    /**
     * Remet une contravention annulée en circulation : elle retrouve le statut
     * que dicte ce qui a été versé et redevient exigible. Refusé si la période
     * est clôturée.
     */
    @PatchMapping("/{id}/restaurer")
    public ContraventionResponse restaurer(@PathVariable Long id) {
        return mapper.toResponse(restaurerContraventionUseCase.execute(id));
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

    // ── Reversement par quittance de l'État ─────────────────────────────────

    /** Prévisualise une quittance de paiement : extraction + rapprochement. Rien n'est reversé. */
    @PostMapping(value = "/reversements/importer", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApercuReversementResponse importerQuittance(@RequestPart("fichier") MultipartFile fichier)
            throws IOException {
        ApercuReversementQuittance apercu = previewReversementQuittanceUseCase.previsualiser(
                fichier.getInputStream(), fichier.getOriginalFilename(), fichier.getContentType());
        return mapper.toApercuReversementResponse(apercu);
    }

    /** Confirme le reversement des contraventions sélectionnées (REVERSE + dépense). */
    @PostMapping("/reversements/confirmer")
    public ResultatReversementResponse confirmerReversement(
            @Valid @RequestBody ConfirmerReversementRequest request) {
        ResultatReversementQuittance resultat = confirmerReversementQuittanceUseCase.confirmer(
                request.contraventionIds(), request.referenceQuittance());
        return mapper.toResultatReversementResponse(resultat);
    }
}
