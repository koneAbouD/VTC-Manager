package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
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
public class CreateChauffeurUseCase {

    private static final String PERMIS_PREFIX   = "chauffeurs/permis/";
    private static final String PHOTO_PREFIX    = "chauffeurs/photos/";
    private static final String TYPE_PERMIS_NOM = "Permis de conduire";

    private final ChauffeurRepository chauffeurRepository;
    private final TypeDocumentRepository typeDocumentRepository;
    private final DocumentRepository documentRepository;
    private final FileStoragePort fileStoragePort;
    private final SyncChauffeurAccountUseCase syncChauffeurAccountUseCase;

    @Transactional
    public Chauffeur execute(Chauffeur chauffeur,
                             String numeroPermis,
                             Set<TypePermis> typesPermis,
                             LocalDate dateEmissionPermis,
                             LocalDate dateExpirationPermis,
                             MultipartFile permisFile,
                             MultipartFile photoIdentiteFile) {
        if (chauffeur.getStatut() == null) {
            chauffeur.setStatut(ChauffeurStatus.ACTIF);
        }

        Chauffeur saved = chauffeurRepository.save(chauffeur);

        // Permis de conduire → Document générique
        sauvegarderPermisDocument(saved.getId(), numeroPermis, typesPermis,
                dateEmissionPermis, dateExpirationPermis, permisFile);

        if (photoIdentiteFile != null && !photoIdentiteFile.isEmpty()) {
            saved.setPhotoUrl(uploaderFichier(photoIdentiteFile, PHOTO_PREFIX));
            saved = chauffeurRepository.save(saved);
        }

        Chauffeur resultat = chauffeurRepository.findById(saved.getId()).orElse(saved);
        syncChauffeurAccountUseCase.synchroniser(resultat);
        return chauffeurRepository.findById(saved.getId()).orElse(resultat);
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
