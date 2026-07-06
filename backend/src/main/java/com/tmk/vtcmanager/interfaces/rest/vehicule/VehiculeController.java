package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.CreateVehiculeCommand;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculePhoto;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.ports.persistence.VehiculePhotoRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import com.tmk.vtcmanager.application.usecases.document.GetDocumentsByVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.CreateVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.DeleteVehiculePhotoUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.DeleteVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.GetAllVehiculesUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.GetVehiculeByIdUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.UpdateVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.UploadVehiculePhotoUseCase;
import com.tmk.vtcmanager.interfaces.rest.document.dto.DocumentResponse;
import com.tmk.vtcmanager.interfaces.rest.document.mapper.DocumentRestMapper;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.UpdateVehiculeRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.VehiculeRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeDetailResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculePhotoResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.VehiculeRestMapper;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/vehicules")
@RequiredArgsConstructor
public class VehiculeController {

    private final CreateVehiculeUseCase createVehiculeUseCase;
    private final UpdateVehiculeUseCase updateVehiculeUseCase;
    private final DeleteVehiculeUseCase deleteVehiculeUseCase;
    private final GetVehiculeByIdUseCase getVehiculeByIdUseCase;
    private final GetAllVehiculesUseCase getAllVehiculesUseCase;
    private final UploadVehiculePhotoUseCase uploadVehiculePhotoUseCase;
    private final DeleteVehiculePhotoUseCase deleteVehiculePhotoUseCase;
    private final GetDocumentsByVehiculeUseCase getDocumentsByVehiculeUseCase;
    private final VehiculePhotoRepository photoRepository;
    private final FileStoragePort storage;
    private final VehiculeRestMapper mapper;
    private final DocumentRestMapper documentMapper;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public VehiculeResponse create(@Valid @RequestBody VehiculeRequest request) {
        CreateVehiculeCommand command = mapper.toCommand(request);
        Vehicule created = createVehiculeUseCase.execute(command);
        return mapper.toResponse(created);
    }

    @GetMapping
    public List<VehiculeResponse> findAll() {
        return mapper.toResponseList(getAllVehiculesUseCase.execute());
    }

    @GetMapping("/page")
    public PageResponse<VehiculeResponse> findPage(
            @RequestParam(required = false) VehiculeStatus statut,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var result = getAllVehiculesUseCase.executePage(statut, page, size)
                .map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public VehiculeDetailResponse findById(@PathVariable Long id) {
        VehiculeResponse base = mapper.toResponse(getVehiculeByIdUseCase.execute(id));
        List<DocumentResponse> documents = documentMapper
                .toResponseList(getDocumentsByVehiculeUseCase.execute(id));
        return new VehiculeDetailResponse(
                base.id(), base.immatriculation(),
                base.marque(), base.modele(),
                base.numeroChassis(),
                base.numeroTelephoneBalise(), base.identifiantBalise(),
                base.couleur(), base.kilometrage(), base.statut(),
                base.type(), base.activite(), base.groupe(),
                base.dateAchat(), base.dateProchaineMaintenance(),
                base.dateMiseEnCirculation(), base.dateEntreeFlotte(),
                base.photos(), documents);
    }

    @PutMapping("/{id}")
    public VehiculeResponse update(@PathVariable Long id, @Valid @RequestBody UpdateVehiculeRequest request) {
        return mapper.toResponse(updateVehiculeUseCase.execute(id, mapper.toCommand(request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteVehiculeUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    // ── Photos ───────────────────────────────────────────────────────────────

    @PostMapping(value = "/{id}/photos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public VehiculePhotoResponse uploadPhoto(@PathVariable Long id,
                                              @RequestParam("file") MultipartFile file) {
        VehiculePhoto photo = uploadVehiculePhotoUseCase.execute(id, file);
        return mapper.toPhotoResponse(photo);
    }

    @DeleteMapping("/{id}/photos/{photoId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePhoto(@PathVariable Long id, @PathVariable Long photoId) {
        deleteVehiculePhotoUseCase.execute(id, photoId);
    }

    @GetMapping("/{id}/photos/{photoId}/download")
    public ResponseEntity<InputStreamResource> downloadPhoto(@PathVariable Long id,
                                                              @PathVariable Long photoId) {
        VehiculePhoto photo = photoRepository.findByIdAndVehiculeId(photoId, id)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Photo introuvable."));
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .body(new InputStreamResource(storage.download(photo.getObjectName())));
    }
}
