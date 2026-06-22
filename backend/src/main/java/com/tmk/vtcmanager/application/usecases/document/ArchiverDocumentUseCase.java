package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;

@Slf4j
@Service
@RequiredArgsConstructor
public class ArchiverDocumentUseCase {

    private static final String ARCHIVE_PREFIX = "archive/";

    private final DocumentRepository documentRepository;
    private final FileStoragePort fileStoragePort;

    public Document execute(Long documentId, String archivedBy, String raison) {
        Document document = documentRepository.findById(documentId)
                .orElseThrow(() -> ResourceNotFoundException.of("Document", documentId));

        if (document.getStatut() == DocumentStatut.ARCHIVE) {
            throw new IllegalStateException("Le document est déjà archivé");
        }

        String ancienUrl = document.getFichierUrl();
        if (ancienUrl != null && !ancienUrl.isBlank()) {
            String nouvelUrl = ARCHIVE_PREFIX + ancienUrl;
            deplacerFichierDansMinIO(ancienUrl, nouvelUrl);
            document.setFichierUrl(nouvelUrl);
        }

        document.setStatut(DocumentStatut.ARCHIVE);
        document.setDateArchivage(LocalDate.now());
        document.setArchivedBy(archivedBy);
        document.setRaisonArchivage(raison);

        return documentRepository.save(document);
    }

    private void deplacerFichierDansMinIO(String source, String destination) {
        try {
            fileStoragePort.copy(source, destination);
            fileStoragePort.delete(source);
        } catch (Exception e) {
            // Si l'objet source n'existe plus dans MinIO (déjà supprimé ou jamais uploadé),
            // on loggue un avertissement mais on n'empêche pas l'archivage des métadonnées.
            log.warn("Impossible de déplacer le fichier MinIO '{}' vers '{}' : {}",
                    source, destination, e.getMessage());
        }
    }
}