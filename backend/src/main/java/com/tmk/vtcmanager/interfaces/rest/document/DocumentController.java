package com.tmk.vtcmanager.interfaces.rest.document;

import com.tmk.vtcmanager.application.usecases.document.*;
import com.tmk.vtcmanager.interfaces.rest.document.dto.ArchiverDocumentRequest;
import com.tmk.vtcmanager.interfaces.rest.document.dto.DocumentPresignedUrlResponse;
import com.tmk.vtcmanager.interfaces.rest.document.dto.DocumentResponse;
import com.tmk.vtcmanager.interfaces.rest.document.dto.UploadDocumentRequest;
import com.tmk.vtcmanager.interfaces.rest.document.mapper.DocumentRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/v1/documents")
@RequiredArgsConstructor
@Tag(name = "Documents (GED)", description = "Gestion électronique des documents véhicules et chauffeurs")
public class DocumentController {

    private final UploadDocumentUseCase uploadDocumentUseCase;
    private final DownloadDocumentUseCase downloadDocumentUseCase;
    private final DeleteDocumentUseCase deleteDocumentUseCase;
    private final GetDocumentsByVehiculeUseCase getByVehiculeUseCase;
    private final GetDocumentsByChauffeurUseCase getByChauffeurUseCase;
    private final ArchiverDocumentUseCase archiverDocumentUseCase;
    private final GenerateDocumentPresignedUrlUseCase generatePresignedUrlUseCase;
    private final DocumentRestMapper mapper;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Uploader un document", description = "Upload vers MinIO + sauvegarde des métadonnées")
    public ResponseEntity<DocumentResponse> upload(
            @RequestPart("metadata") @Valid UploadDocumentRequest request,
            @RequestPart("fichier") MultipartFile fichier) throws IOException {

        var document = mapper.toDomain(request);
        document.setFichierNom(fichier.getOriginalFilename());

        var saved = uploadDocumentUseCase.execute(
                document,
                fichier.getInputStream(),
                fichier.getSize(),
                fichier.getContentType());

        return ResponseEntity.status(HttpStatus.CREATED).body(mapper.toResponse(saved));
    }

    @GetMapping("/{id}/download")
    @Operation(summary = "Télécharger un document depuis MinIO")
    public ResponseEntity<InputStreamResource> download(@PathVariable Long id) {
        var stream = downloadDocumentUseCase.execute(id);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment")
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(new InputStreamResource(stream));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Supprimer un document (MinIO + BDD)")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteDocumentUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/vehicule/{vehiculeId}")
    @Operation(summary = "Documents d'un véhicule")
    public ResponseEntity<List<DocumentResponse>> getByVehicule(@PathVariable Long vehiculeId) {
        return ResponseEntity.ok(mapper.toResponseList(getByVehiculeUseCase.execute(vehiculeId)));
    }

    @GetMapping("/chauffeur/{chauffeurId}")
    @Operation(summary = "Documents d'un chauffeur")
    public ResponseEntity<List<DocumentResponse>> getByChauffeur(@PathVariable Long chauffeurId) {
        return ResponseEntity.ok(mapper.toResponseList(getByChauffeurUseCase.execute(chauffeurId)));
    }

    @GetMapping("/{id}/presigned-url")
    @Operation(summary = "Obtenir une URL présignée (15 min) pour télécharger un document depuis MinIO")
    public ResponseEntity<DocumentPresignedUrlResponse> getPresignedUrl(@PathVariable Long id) {
        var doc = generatePresignedUrlUseCase.execute(id);
        return ResponseEntity.ok(new DocumentPresignedUrlResponse(
                doc.getFichierUrl(),
                doc.getFichierNom(),
                doc.getFichierType()
        ));
    }

    @PostMapping("/{id}/archiver")
    @Operation(summary = "Archiver un document",
               description = "Déplace le fichier dans MinIO (prefix archive/) et marque le document comme ARCHIVE")
    public ResponseEntity<DocumentResponse> archiver(
            @PathVariable Long id,
            @Valid @RequestBody ArchiverDocumentRequest request,
            @AuthenticationPrincipal Jwt jwt) {
        String userId = jwt.getSubject();
        var archived = archiverDocumentUseCase.execute(id, userId, request.raisonArchivage());
        return ResponseEntity.ok(mapper.toResponse(archived));
    }
}