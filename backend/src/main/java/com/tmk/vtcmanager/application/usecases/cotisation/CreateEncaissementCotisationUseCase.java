package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.EncaissementDepasseMontantDuException;
import com.tmk.vtcmanager.application.exception.LigneCotisationDejaSoldeeException;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@RequiredArgsConstructor
public class CreateEncaissementCotisationUseCase {

    private static final String CODE_CATEGORIE = "ENCAISSEMENT_COTISATIONS";

    private final LigneCotisationRepository ligneCotisationRepository;
    private final EncaissementCotisationRepository encaissementCotisationRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final CategorieOperationRepository categorieOperationRepository;

    @Transactional
    public EncaissementCotisation executer(Long ligneCotisationId, EncaissementCotisation encaissement) {
        LigneCotisation ligne = ligneCotisationRepository.findById(ligneCotisationId)
                .orElseThrow(() -> new LigneCotisationNotFoundException(ligneCotisationId));

        if (!ligne.estActive()) {
            throw new LigneCotisationDejaSoldeeException(ligneCotisationId);
        }

        if (encaissement.getMontant().compareTo(ligne.montantRestant()) > 0) {
            throw new EncaissementDepasseMontantDuException(ligne.montantRestant());
        }

        encaissement.setLigneCotisationId(ligneCotisationId);

        OperationFinanciere operation = creerOperation(ligne, encaissement);
        encaissement.setOperationFinanciereId(operation.getId());

        EncaissementCotisation saved = encaissementCotisationRepository.save(encaissement);

        // Recalcul fiable depuis la BDD (source de vérité), une instruction atomique.
        ligneCotisationRepository.recalculerDepuisEncaissements(ligneCotisationId);

        return saved;
    }

    private OperationFinanciere creerOperation(LigneCotisation ligne, EncaissementCotisation encaissement) {
        CategorieOperation categorie = categorieOperationRepository.findByCode(CODE_CATEGORIE).orElse(null);

        com.tmk.vtcmanager.application.domain.vehicule.Vehicule vehicule =
                new com.tmk.vtcmanager.application.domain.vehicule.Vehicule();
        vehicule.setId(ligne.getVehiculeId());

        com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur chauffeur =
                new com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur();
        chauffeur.setId(ligne.getChauffeurId());

        OperationFinanciere op = OperationFinanciere.builder()
                .typeOperation(TypeOperation.REVENU)
                .categorie(categorie)
                .vehicule(vehicule)
                .chauffeur(chauffeur)
                .montant(encaissement.getMontant())
                .modePaiement(encaissement.getModeEncaissement())
                .dateOperation(encaissement.getDateEncaissement())
                .dateReference(ligne.getDateCotisation())
                .commentaire(encaissement.getCommentaire() != null && !encaissement.getCommentaire().isBlank()
                        ? encaissement.getCommentaire()
                        : ligne.getNomCotisation())
                .reference(genererReference())
                .statut(StatutOperation.ENCAISSE)
                .build();

        return operationFinanciereRepository.save(op);
    }

    private String genererReference() {
        String ts = String.valueOf(System.currentTimeMillis()).substring(7);
        return "COT-" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy")) + "-" + ts;
    }
}
