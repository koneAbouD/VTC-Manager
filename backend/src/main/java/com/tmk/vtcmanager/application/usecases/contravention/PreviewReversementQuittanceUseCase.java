package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.contravention.reversement.ApercuReversementQuittance;
import com.tmk.vtcmanager.application.domain.contravention.reversement.LigneReversement;
import com.tmk.vtcmanager.application.domain.contravention.reversement.StatutLigneReversement;
import com.tmk.vtcmanager.application.ports.extraction.LigneQuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversementExtractorPort;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

/**
 * Prévisualise une quittance de paiement de l'État : archive le document, extrait
 * les lignes réglées, rapproche chaque numéro de contravention avec la base et
 * classe le résultat ({@code A_REVERSER} / {@code DEJA_REVERSEE} / {@code INTROUVABLE}).
 * Rien n'est modifié ici — le reversement effectif revient à
 * {@link ConfirmerReversementQuittanceUseCase}.
 */
@RequiredArgsConstructor
public class PreviewReversementQuittanceUseCase {

    private final QuittanceReversementExtractorPort extractor;
    private final ContraventionRepository contraventionRepository;
    private final FileStoragePort fileStoragePort;

    public ApercuReversementQuittance previsualiser(InputStream fichier, String nomFichier, String contentType) {
        // 1. Archivage du document source (traçabilité).
        byte[] octets = lireTout(fichier);
        String objectName = "reversements/" + UUID.randomUUID() + "/"
                + (nomFichier != null ? nomFichier : "quittance.pdf");
        fileStoragePort.upload(objectName, new ByteArrayInputStream(octets),
                octets.length, contentType != null ? contentType : "application/pdf");

        // 2. Extraction de la quittance.
        QuittanceReversement quittance = extractor.extraire(new ByteArrayInputStream(octets));

        ApercuReversementQuittance apercu = ApercuReversementQuittance.builder()
                .numeroLiquidation(quittance.numeroLiquidation())
                .numeroDemande(quittance.numeroDemande())
                .demandeur(quittance.demandeur())
                .dateQuittance(quittance.dateQuittance())
                .documentSourcePath(objectName)
                .build();

        // 3. Rapprochement ligne à ligne par numéro de contravention.
        for (LigneQuittanceReversement l : quittance.lignes()) {
            apercu.getLignes().add(rapprocher(l));
        }
        return apercu;
    }

    private LigneReversement rapprocher(LigneQuittanceReversement l) {
        LigneReversement.LigneReversementBuilder ligne = LigneReversement.builder()
                .numeroContravention(l.numeroContravention())
                .plaque(l.plaque())
                .codeInfraction(l.codeInfraction())
                .montantQuittance(l.montant());

        Optional<Contravention> match = contraventionRepository.findByNumero(l.numeroContravention());
        if (match.isEmpty()) {
            return ligne.statut(StatutLigneReversement.INTROUVABLE).build();
        }

        Contravention c = match.get();
        BigDecimal montantSysteme = c.getMontant();
        boolean divergent = l.montant() != null && montantSysteme != null
                && l.montant().compareTo(montantSysteme) != 0;

        StatutLigneReversement statut = c.getStatut() == ContraventionStatus.REVERSE
                ? StatutLigneReversement.DEJA_REVERSEE
                : StatutLigneReversement.A_REVERSER;

        return ligne
                .contraventionId(c.getId())
                .montantSysteme(montantSysteme)
                .montantDivergent(divergent)
                .statut(statut)
                .build();
    }

    private static byte[] lireTout(InputStream in) {
        try {
            return in.readAllBytes();
        } catch (IOException e) {
            throw new UncheckedIOException("Lecture de la quittance impossible", e);
        }
    }
}
