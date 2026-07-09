package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.contravention.ApercuImportContraventions;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.StatutRattachement;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtractorPort;
import com.tmk.vtcmanager.application.ports.extraction.ContraventionExtraite;
import com.tmk.vtcmanager.application.ports.extraction.ReleveContraventions;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.Optional;
import java.util.UUID;

/**
 * Prévisualise un relevé de contraventions PDF : extrait les lignes, résout le
 * véhicule par sa plaque, propose le chauffeur responsable via le programme de
 * travail, écarte les doublons et archive le PDF. Rien n'est persisté ici — la
 * confirmation revient à {@link ConfirmerImportContraventionsUseCase}.
 */
@RequiredArgsConstructor
public class ImporterContraventionsUseCase {

    private final ContraventionExtractorPort extractor;
    private final VehiculeRepository vehiculeRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ContraventionRepository contraventionRepository;
    private final FileStoragePort fileStoragePort;

    public ApercuImportContraventions previsualiser(InputStream pdf, String nomFichier, String contentType) {
        // 1. Archivage du PDF source (traçabilité) — la clé est renvoyée à la confirmation.
        byte[] octets = lireTout(pdf);
        String objectName = "contraventions/" + UUID.randomUUID() + "/"
                + (nomFichier != null ? nomFichier : "releve.pdf");
        fileStoragePort.upload(objectName, new ByteArrayInputStream(octets),
                octets.length, contentType != null ? contentType : "application/pdf");

        // 2. Extraction du relevé.
        ReleveContraventions releve = extractor.extraire(new ByteArrayInputStream(octets));

        // 3. Résolution du véhicule par la plaque.
        Optional<Vehicule> vehicule = releve.plaque() != null
                ? vehiculeRepository.findByImmatriculation(releve.plaque())
                : Optional.empty();
        Long vehiculeId = vehicule.map(Vehicule::getId).orElse(null);
        ProgrammeTravail programme = vehiculeId != null
                ? programmeTravailRepository.findByVehiculeId(vehiculeId).orElse(null)
                : null;

        ApercuImportContraventions apercu = ApercuImportContraventions.builder()
                .plaque(releve.plaque())
                .vehiculeId(vehiculeId)
                .vehiculeImmatriculation(vehicule.map(Vehicule::getImmatriculation).orElse(releve.plaque()))
                .vehiculeInconnu(vehiculeId == null)
                .documentSourcePath(objectName)
                .build();

        // 4. Construction des candidats (doublons écartés, chauffeur proposé).
        for (ContraventionExtraite c : releve.contraventions()) {
            if (contraventionRepository.existsByNumero(c.numeroContravention())) {
                apercu.getDoublonsIgnores().add(c.numeroContravention());
                continue;
            }
            apercu.getCandidats().add(construireCandidat(c, vehicule.orElse(null), programme, apercu.getDocumentSourcePath()));
        }
        return apercu;
    }

    private Contravention construireCandidat(ContraventionExtraite c, Vehicule vehicule,
                                             ProgrammeTravail programme, String documentSourcePath) {
        Long chauffeurId = programme != null
                ? programme.chauffeurResponsable(c.dateInfraction(), c.heureInfraction())
                : null;
        StatutRattachement statut = chauffeurId != null
                ? StatutRattachement.AUTO
                : StatutRattachement.A_RATTACHER;

        Chauffeur chauffeur = chauffeurId != null
                ? chauffeurRepository.findById(chauffeurId).orElse(null)
                : null;

        return Contravention.builder()
                .numeroContravention(c.numeroContravention())
                .vehicule(vehicule)
                .chauffeur(chauffeur)
                .codeInfraction(c.codeInfraction())
                .typeInfraction(c.libelleInfraction())
                .description(c.libelleInfraction())
                .dateInfraction(c.dateInfraction())
                .heureInfraction(c.heureInfraction())
                .vitesseRelevee(c.vitesseRelevee())
                .lieu(c.lieuInfraction())
                .montant(c.montant())
                .statutRattachement(statut)
                .documentSourcePath(documentSourcePath)
                .build();
    }

    private static byte[] lireTout(InputStream in) {
        try {
            return in.readAllBytes();
        } catch (IOException e) {
            throw new UncheckedIOException("Lecture du PDF impossible", e);
        }
    }
}
