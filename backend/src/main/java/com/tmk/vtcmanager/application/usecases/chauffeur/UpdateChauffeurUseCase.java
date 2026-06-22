package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDate;
import java.util.Set;
import java.util.UUID;

@RequiredArgsConstructor
public class UpdateChauffeurUseCase {

    private static final String PERMIS_PREFIX   = "chauffeurs/permis/";
    private static final String PHOTO_PREFIX    = "chauffeurs/photos/";
    private static final String TYPE_PERMIS_NOM = "Permis de conduire";

    private final ChauffeurRepository chauffeurRepository;
    private final DocumentRepository documentRepository;
    private final TypeDocumentRepository typeDocumentRepository;
    private final FileStoragePort fileStoragePort;

    @Transactional
    public Chauffeur execute(Long id, Chauffeur data,
                             String numeroPermis,
                             Set<TypePermis> typesPermis,
                             LocalDate dateEmissionPermis,
                             LocalDate dateExpirationPermis,
                             MultipartFile permisFile,
                             MultipartFile photoIdentiteFile,
                             boolean deletePhoto) {
        Chauffeur existing = chauffeurRepository.findById(id)
                .orElseThrow(() -> new ChauffeurNotFoundException(id));

        existing.setNom(data.getNom());
        existing.setPrenom(data.getPrenom());
        existing.setGenre(data.getGenre());
        existing.setType(data.getType());
        existing.setDateNaissance(data.getDateNaissance());
        existing.setTelephone(data.getTelephone());
        existing.setEmail(data.getEmail());
        existing.setAdresse(data.getAdresse());
        if (data.getStatut() != null) existing.setStatut(data.getStatut());
        existing.setDateEmbauche(data.getDateEmbauche());

        if (deletePhoto) {
            String oldPhoto = existing.getPhotoUrl();
            if (oldPhoto != null && !oldPhoto.isBlank()) {
                try { fileStoragePort.delete(oldPhoto); } catch (Exception ignored) {}
            }
            existing.setPhotoUrl(null);
        }

        if (photoIdentiteFile != null && !photoIdentiteFile.isEmpty()) {
            existing.setPhotoUrl(uploaderFichier(photoIdentiteFile, PHOTO_PREFIX));
        }

        chauffeurRepository.save(existing);

        if (permisFile != null && !permisFile.isEmpty()) {
            sauvegarderPermisDocument(id, numeroPermis, typesPermis,
                    dateEmissionPermis, dateExpirationPermis, permisFile);
        }

        return chauffeurRepository.findById(id)
                .orElseThrow(() -> new ChauffeurNotFoundException(id));
    }

    private void sauvegarderPermisDocument(Long chauffeurId, String numero, Set<TypePermis> types,
                                            LocalDate dateEmission, LocalDate dateExpiration,
                                            MultipartFile fichier) {
        String objectName = uploaderFichier(fichier, PERMIS_PREFIX);
        typeDocumentRepository.findByNom(TYPE_PERMIS_NOM).ifPresent(type -> {
            Document permis = Document.builder()
                    .typeDocument(type)
                    .reference(numero)
                    .permanence(dateExpiration == null)
                    .categorie(types)
                    .dateEmission(dateEmission)
                    .dateExpiration(dateExpiration)
                    .statut(DocumentStatut.EN_ATTENTE)
                    .fichierUrl(objectName)
                    .fichierNom(fichier.getOriginalFilename())
                    .fichierType(fichier.getContentType())
                    .cible(CibleDocument.CHAUFFEUR)
                    .cibleId(chauffeurId)
                    .build();
            documentRepository.save(permis);
        });
    }

    private String uploaderFichier(MultipartFile fichier, String prefix) {
        try {
            String objectName = prefix + UUID.randomUUID() + "_" + fichier.getOriginalFilename();
            return fileStoragePort.upload(objectName, fichier.getInputStream(),
                    fichier.getSize(), fichier.getContentType());
        } catch (IOException e) {
            throw new RuntimeException("Erreur upload fichier : " + e.getMessage(), e);
        }
    }
}
