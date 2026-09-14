package com.tmk.vtcmanager.application.usecases.versement;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.versement.PartVersement;
import com.tmk.vtcmanager.application.domain.versement.SaisieVersement;
import com.tmk.vtcmanager.application.domain.versement.VersementEnregistre;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.exception.VersementIncoherentException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.usecases.cotisation.CreateEncaissementCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.recette.CreateEncaissementUseCase;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * Encaisse d'un même geste la recette et la cotisation du jour.
 *
 * <p>Le chauffeur remet un seul billet. Le journal en garde pourtant deux
 * écritures, et doit les garder : la recette est un produit, la cotisation un
 * dépôt détenu pour lui. Ce que ce use case ajoute, c'est le lien — un
 * identifiant de versement commun, qui permet de les montrer et de les
 * quittancer ensemble sans rien changer à ce que chacune compte.
 *
 * <p><b>Tout ou rien.</b> Les deux encaissements rejoignent la transaction de
 * ce use case : si la cotisation est refusée — caisse comptée, montant qui
 * dépasse le dû — la recette ne passe pas non plus. Un billet ne se coupe pas
 * en deux au guichet ; le client n'a plus à gérer le cas bâtard d'un versement
 * à moitié enregistré.
 *
 * <p>Chaque encaissement garde ses propres refus : ceux-ci vivent dans les use
 * cases unitaires, qui sont appelés tels quels.
 */
@RequiredArgsConstructor
public class EncaisserVersementUseCase {

    private final CreateEncaissementUseCase createEncaissementUseCase;
    private final CreateEncaissementCotisationUseCase createEncaissementCotisationUseCase;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;

    @Transactional
    public VersementEnregistre executer(SaisieVersement saisie) {
        PartVersement recette = saisie.recette();
        PartVersement cotisation = saisie.cotisation();
        if (recette == null && cotisation == null) {
            throw new IllegalArgumentException(
                    "Un versement doit solder au moins une créance : la recette, la cotisation, ou les deux.");
        }
        if (recette != null && cotisation != null) {
            verifierSoeurs(recette.ligneId(), cotisation.ligneId());
        }

        // Dans l'ordre où le guichet les voit : la recette, puis sa cotisation.
        Encaissement encaissementRecette = recette == null ? null
                : createEncaissementUseCase.executer(recette.ligneId(), Encaissement.builder()
                        .montant(recette.montant())
                        .modeEncaissement(saisie.mode())
                        .dateEncaissement(saisie.date())
                        .reference(saisie.reference())
                        .commentaire(saisie.commentaire())
                        .build());

        EncaissementCotisation encaissementCotisation = cotisation == null ? null
                : createEncaissementCotisationUseCase.executer(cotisation.ligneId(),
                        EncaissementCotisation.builder()
                                .montant(cotisation.montant())
                                .modeEncaissement(saisie.mode())
                                .dateEncaissement(saisie.date())
                                .reference(saisie.reference())
                                .commentaire(saisie.commentaire())
                                .build());

        UUID versementId = rattacher(encaissementRecette, encaissementCotisation);

        return new VersementEnregistre(versementId,
                encaissementRecette == null ? null : encaissementRecette.getId(),
                encaissementCotisation == null ? null : encaissementCotisation.getId());
    }

    /**
     * Une recette et une cotisation ne forment un versement que si elles sont
     * sœurs : même véhicule, même chauffeur, même jour. Sans ce contrôle, un
     * client pourrait rassembler deux dettes sans rapport sous une seule pièce.
     */
    private void verifierSoeurs(Long ligneRecetteId, Long ligneCotisationId) {
        LigneRecette ligneRecette = ligneRecetteRepository.findById(ligneRecetteId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneRecetteId));
        LigneCotisation ligneCotisation = ligneCotisationRepository.findById(ligneCotisationId)
                .orElseThrow(() -> new LigneCotisationNotFoundException(ligneCotisationId));

        boolean soeurs = Objects.equals(ligneRecette.getVehiculeId(), ligneCotisation.getVehiculeId())
                && Objects.equals(ligneRecette.getChauffeurId(), ligneCotisation.getChauffeurId())
                && Objects.equals(ligneRecette.getDateRecette(), ligneCotisation.getDateCotisation());
        if (!soeurs) {
            throw new VersementIncoherentException(
                    "Cette recette et cette cotisation ne portent pas le même véhicule, le même"
                            + " chauffeur et le même jour : elles ne peuvent pas être réglées par un"
                            + " seul versement. Encaissez-les séparément.");
        }
    }

    /** Pose l'identifiant commun, quand il y a bien deux écritures à rassembler. */
    private UUID rattacher(Encaissement recette, EncaissementCotisation cotisation) {
        if (recette == null || cotisation == null) return null;
        Long operationRecette = recette.getOperationFinanciereId();
        Long operationCotisation = cotisation.getOperationFinanciereId();
        if (operationRecette == null || operationCotisation == null) return null;

        UUID versementId = UUID.randomUUID();
        operationFinanciereRepository.rattacherAuVersement(
                List.of(operationRecette, operationCotisation), versementId);
        return versementId;
    }
}
