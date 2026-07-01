package com.tmk.vtcmanager.interfaces.rest.chauffeur;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import com.tmk.vtcmanager.application.usecases.chauffeur.AssignVehiculeToChauffeurUseCase;
import com.tmk.vtcmanager.application.usecases.chauffeur.CreateChauffeurUseCase;
import com.tmk.vtcmanager.application.usecases.chauffeur.DeleteChauffeurUseCase;
import com.tmk.vtcmanager.application.usecases.chauffeur.GetAllChauffeursUseCase;
import com.tmk.vtcmanager.application.usecases.chauffeur.GetChauffeurByIdUseCase;
import com.tmk.vtcmanager.application.usecases.chauffeur.UnassignVehiculeFromChauffeurUseCase;
import com.tmk.vtcmanager.application.usecases.chauffeur.UpdateChauffeurUseCase;
import com.tmk.vtcmanager.application.usecases.document.GetDocumentsByChauffeurUseCase;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.request.ChauffeurRequest;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurDetailResponse;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.mapper.ChauffeurRestMapper;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.document.mapper.DocumentRestMapper;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.ProgrammeTravailRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.List;

@RestController
@RequestMapping("/api/chauffeurs")
@RequiredArgsConstructor
public class ChauffeurController {

    private final CreateChauffeurUseCase createChauffeurUseCase;
    private final UpdateChauffeurUseCase updateChauffeurUseCase;
    private final DeleteChauffeurUseCase deleteChauffeurUseCase;
    private final GetChauffeurByIdUseCase getChauffeurByIdUseCase;
    private final GetAllChauffeursUseCase getAllChauffeursUseCase;
    private final AssignVehiculeToChauffeurUseCase assignVehiculeToChauffeurUseCase;
    private final UnassignVehiculeFromChauffeurUseCase unassignVehiculeFromChauffeurUseCase;
    private final GetDocumentsByChauffeurUseCase getDocumentsByChauffeurUseCase;
    private final ChauffeurRestMapper mapper;
    private final DocumentRestMapper documentMapper;
    private final ProgrammeTravailRestMapper programmeMapper;
    private final FileStoragePort fileStoragePort;

    @PostMapping(consumes = "multipart/form-data")
    @ResponseStatus(HttpStatus.CREATED)
    public ChauffeurResponse create(
            @RequestPart("data") @Valid ChauffeurRequest request,
            @RequestPart("permis") MultipartFile permisFile,
            @RequestPart(value = "photo", required = false) MultipartFile photoIdentiteFile) {

        Chauffeur created = createChauffeurUseCase.execute(
                mapper.toDomain(request),
                request.numeroPermis(),
                request.typesPermis(),
                request.dateEmissionPermis(),
                request.dateExpirationPermis(),
                permisFile,
                photoIdentiteFile
        );
        return mapper.toResponse(created);
    }

    @GetMapping
    public List<ChauffeurResponse> findAll() {
        return mapper.toResponseList(getAllChauffeursUseCase.execute());
    }

    @GetMapping("/page")
    public PageResponse<ChauffeurResponse> findPage(
            @RequestParam(required = false) ChauffeurStatus statut,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var result = getAllChauffeursUseCase.executePage(statut, page, size)
                .map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public ChauffeurDetailResponse findById(@PathVariable Long id) {
        var result = getChauffeurByIdUseCase.execute(id);
        var chauffeur = mapper.toResponse(result.chauffeur());
        var programme = result.programmeTravail() != null
                ? programmeMapper.toResponse(result.programmeTravail())
                : null;
        var documents = documentMapper.toResponseList(getDocumentsByChauffeurUseCase.execute(id));
        return ChauffeurDetailResponse.from(chauffeur, programme, documents);
    }

    @PutMapping(value = "/{id}", consumes = "multipart/form-data")
    public ChauffeurResponse update(
            @PathVariable Long id,
            @RequestPart("data") @Valid ChauffeurRequest request,
            @RequestPart(value = "permis", required = false) MultipartFile permisFile,
            @RequestPart(value = "photo", required = false) MultipartFile photoIdentiteFile) {

        Chauffeur updated = updateChauffeurUseCase.execute(
                id,
                mapper.toDomain(request),
                request.numeroPermis(),
                request.typesPermis(),
                request.dateEmissionPermis(),
                request.dateExpirationPermis(),
                permisFile,
                photoIdentiteFile,
                Boolean.TRUE.equals(request.deletePhoto())
        );
        return mapper.toResponse(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteChauffeurUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{chauffeurId}/vehicule/{vehiculeId}")
    public ChauffeurResponse assignVehicule(@PathVariable Long chauffeurId, @PathVariable Long vehiculeId) {
        return mapper.toResponse(assignVehiculeToChauffeurUseCase.execute(chauffeurId, vehiculeId));
    }

    @DeleteMapping("/{chauffeurId}/vehicule")
    public ChauffeurResponse unassignVehicule(@PathVariable Long chauffeurId) {
        return mapper.toResponse(unassignVehiculeFromChauffeurUseCase.execute(chauffeurId));
    }

    /**
     * Streame la photo d'identité d'un chauffeur depuis MinIO.
     * Utilisé par les clients pour afficher la miniature sans avoir à
     * manipuler directement les object names MinIO.
     */
    @GetMapping("/{id}/photo")
    public ResponseEntity<InputStreamResource> getPhoto(@PathVariable Long id) {
        Chauffeur chauffeur = getChauffeurByIdUseCase.execute(id).chauffeur();
        String objectName = chauffeur.getPhotoUrl();
        if (objectName == null || objectName.isBlank()) {
            return ResponseEntity.notFound().build();
        }
        InputStream stream = fileStoragePort.download(objectName);
        String lower = objectName.toLowerCase();
        MediaType mediaType;
        if (lower.endsWith(".png")) {
            mediaType = MediaType.IMAGE_PNG;
        } else if (lower.endsWith(".gif")) {
            mediaType = MediaType.IMAGE_GIF;
        } else if (lower.endsWith(".webp")) {
            mediaType = MediaType.valueOf("image/webp");
        } else {
            mediaType = MediaType.IMAGE_JPEG;
        }
        return ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CACHE_CONTROL, "private, max-age=300")
                .body(new InputStreamResource(stream));
    }
}
