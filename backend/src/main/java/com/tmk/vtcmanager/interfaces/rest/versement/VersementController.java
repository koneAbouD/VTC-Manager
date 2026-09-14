package com.tmk.vtcmanager.interfaces.rest.versement;

import com.tmk.vtcmanager.application.domain.versement.ImputationVersement;
import com.tmk.vtcmanager.application.domain.versement.PartVersement;
import com.tmk.vtcmanager.application.domain.versement.ResultatVersementLot;
import com.tmk.vtcmanager.application.domain.versement.SaisieVersement;
import com.tmk.vtcmanager.application.domain.versement.Versement;
import com.tmk.vtcmanager.application.domain.versement.VersementEnregistre;
import com.tmk.vtcmanager.application.usecases.versement.EncaisserVersementUseCase;
import com.tmk.vtcmanager.application.usecases.versement.EncaisserVersementsLotUseCase;
import com.tmk.vtcmanager.application.usecases.versement.GetVersementUseCase;
import com.tmk.vtcmanager.interfaces.rest.versement.dto.request.VersementLotRequest;
import com.tmk.vtcmanager.interfaces.rest.versement.dto.request.VersementRequest;
import com.tmk.vtcmanager.interfaces.rest.versement.dto.response.VersementEnregistreResponse;
import com.tmk.vtcmanager.interfaces.rest.versement.dto.response.VersementLotResponse;
import com.tmk.vtcmanager.interfaces.rest.versement.dto.response.VersementResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Versements : un billet remis au guichet pour la recette et la cotisation du
 * jour. Le journal en garde une écriture par créance ; ces routes les créent
 * ensemble et les relisent comme une seule pièce de caisse.
 */
@RestController
@RequestMapping("/api/versements")
@RequiredArgsConstructor
public class VersementController {

    private final EncaisserVersementUseCase encaisserVersementUseCase;
    private final EncaisserVersementsLotUseCase encaisserVersementsLotUseCase;
    private final GetVersementUseCase getVersementUseCase;

    /** Un versement, tout ou rien : recette et cotisation passent ensemble ou pas du tout. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public VersementEnregistreResponse encaisser(@Valid @RequestBody VersementRequest request) {
        VersementEnregistre enregistre = encaisserVersementUseCase.executer(new SaisieVersement(
                part(request.recette()), part(request.cotisation()),
                request.modeEncaissement(), request.dateEncaissement(),
                request.reference(), request.commentaire()));
        return new VersementEnregistreResponse(enregistre.versementId(),
                enregistre.encaissementRecetteId(), enregistre.encaissementCotisationId());
    }

    /**
     * Plusieurs versements d'un même geste de caisse. Toujours 200, même si
     * tout a été refusé : chaque versement porte son verdict.
     */
    @PostMapping("/lot")
    public VersementLotResponse encaisserLot(@Valid @RequestBody VersementLotRequest request) {
        List<SaisieVersement> saisies = request.versements().stream()
                .map(v -> new SaisieVersement(part(v.recette()), part(v.cotisation()),
                        request.modeEncaissement(), request.dateEncaissement(),
                        request.reference(), request.commentaire()))
                .toList();

        List<ResultatVersementLot> resultats = encaisserVersementsLotUseCase.executer(saisies);
        int reussis = (int) resultats.stream().filter(ResultatVersementLot::succes).count();
        return new VersementLotResponse(reussis, resultats.size() - reussis,
                resultats.stream()
                        .map(r -> new VersementLotResponse.ResultatResponse(r.ligneRecetteId(),
                                r.ligneCotisationId(), r.succes(), r.versementId(), r.message()))
                        .toList());
    }

    @GetMapping("/{versementId}")
    public VersementResponse lire(@PathVariable UUID versementId) {
        Versement v = getVersementUseCase.executer(versementId);
        return new VersementResponse(v.versementId(), v.dateEncaissement(), v.modePaiement(),
                v.chauffeurId(), v.chauffeurNom(), v.chauffeurTelephone(),
                v.vehiculeId(), v.vehiculeImmatriculation(), v.total(),
                v.imputations().stream().map(VersementController::toImputation).toList());
    }

    private static VersementResponse.ImputationResponse toImputation(ImputationVersement i) {
        return new VersementResponse.ImputationResponse(i.operationId(), i.reference(), i.nature(),
                i.libelle(), i.ligneId(), i.dateReference(), i.montant(), i.annulee(), i.resteDu());
    }

    private static PartVersement part(VersementRequest.PartRequest part) {
        return part == null ? null : new PartVersement(part.ligneId(), part.montant());
    }
}
