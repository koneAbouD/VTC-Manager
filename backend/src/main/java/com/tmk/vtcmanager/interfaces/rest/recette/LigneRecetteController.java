package com.tmk.vtcmanager.interfaces.rest.recette;

import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.usecases.recette.AnnulerLigneRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.recette.ReaffecterChauffeurRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.recette.RestaurerLigneRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.reaffectation.GetApercuReaffectationUseCase;
import com.tmk.vtcmanager.application.services.ReaffectationChauffeurService;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import com.tmk.vtcmanager.application.usecases.recette.ConfirmerVersementUseCase;
import com.tmk.vtcmanager.application.usecases.recette.CreateEncaissementUseCase;
import com.tmk.vtcmanager.application.usecases.recette.CreateEncaissementsLotUseCase;
import com.tmk.vtcmanager.application.usecases.recette.GenererLignesRecetteUseCase;
import com.tmk.vtcmanager.application.usecases.recette.GetLignesRecetteUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.AnnulationRequest;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.common.ReaffectationChauffeurRequest;
import com.tmk.vtcmanager.interfaces.rest.reaffectation.dto.ApercuReaffectationResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.request.EncaissementLotRequest;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.request.EncaissementRequest;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.EncaissementLotResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.EncaissementResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.LigneRecetteResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.mapper.RecetteRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/recettes/lignes")
@RequiredArgsConstructor
public class LigneRecetteController {

    private final GetLignesRecetteUseCase getLignesRecetteUseCase;
    private final CreateEncaissementUseCase createEncaissementUseCase;
    private final CreateEncaissementsLotUseCase createEncaissementsLotUseCase;
    private final AnnulerLigneRecetteUseCase annulerLigneRecetteUseCase;
    private final RestaurerLigneRecetteUseCase restaurerLigneRecetteUseCase;
    private final ReaffecterChauffeurRecetteUseCase reaffecterChauffeurRecetteUseCase;
    private final VerrouArreteService verrouArreteService;
    private final ReaffectationChauffeurService reaffectationChauffeurService;
    private final GetApercuReaffectationUseCase getApercuReaffectationUseCase;
    private final ConfirmerVersementUseCase confirmerVersementUseCase;
    private final GenererLignesRecetteUseCase genererLignesRecetteUseCase;
    private final RecetteRestMapper mapper;

    @GetMapping
    public List<LigneRecetteResponse> getLignes(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) StatutLigneRecette statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        LigneRecetteFiltres filtres = LigneRecetteFiltres.builder()
                .vehiculeId(vehiculeId)
                .chauffeurId(chauffeurId)
                .statut(statut)
                .dateDebut(dateDebut)
                .dateFin(dateFin)
                .build();
        return mapper.toResponseList(getLignesRecetteUseCase.findByCriteres(filtres));
    }

    @GetMapping("/page")
    public PageResponse<LigneRecetteResponse> getLignesPage(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) StatutLigneRecette statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin,
            @RequestParam(required = false) String recherche,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        LigneRecetteFiltres filtres = LigneRecetteFiltres.builder()
                .vehiculeId(vehiculeId)
                .chauffeurId(chauffeurId)
                .statut(statut)
                .dateDebut(dateDebut)
                .dateFin(dateFin)
                .recherche(recherche)
                .build();
        var result = getLignesRecetteUseCase.findPageByCriteres(filtres, page, size)
                .map(mapper::toResponse);
        return PageResponse.from(result);
    }

    @GetMapping("/{id:\\d+}")
    public LigneRecetteResponse getLigneById(@PathVariable Long id) {
        LigneRecette ligne = getLignesRecetteUseCase.findById(id);
        // Dit au client si l'action « Restaurer » a encore un sens : un arrêté
        // — période close, caisse comptée — peut l'avoir fermée depuis.
        ligne.setRestaurable(verrouArreteService.estRestaurable(ligne.getDateRecette()));
        // Et si le chauffeur peut encore changer : même principe, la fiche dit au
        // client ce qu'elle permet plutôt que de le laisser tenter puis échouer.
        String blocage = reaffectationChauffeurService.motifBlocage(ligne);
        ligne.setReaffectable(blocage == null);
        ligne.setMotifNonReaffectable(blocage);
        return mapper.toResponse(ligne);
    }

    @PostMapping("/{id}/encaissements")
    @ResponseStatus(HttpStatus.CREATED)
    public EncaissementResponse createEncaissement(
            @PathVariable Long id,
            @Valid @RequestBody EncaissementRequest request) {
        return mapper.toResponse(createEncaissementUseCase.executer(id, mapper.toDomain(request)));
    }

    /**
     * Encaissement de masse : un versement du chauffeur solde plusieurs
     * journées d'un coup, avec un montant propre à chaque ligne.
     *
     * <p>Toujours 200, même si tout a été refusé : le lot n'est pas un tout ou
     * rien, et c'est le détail de la réponse qui porte le verdict de chaque
     * ligne — motif compris, rédigé pour être affiché tel quel.
     */
    @PostMapping("/encaissements-lot")
    public EncaissementLotResponse createEncaissementsLot(
            @Valid @RequestBody EncaissementLotRequest request) {
        return mapper.toLotResponse(createEncaissementsLotUseCase.executer(
                mapper.toMontants(request.lignes()),
                request.modeEncaissement(),
                request.dateEncaissement(),
                request.reference(),
                request.commentaire()));
    }

    @GetMapping("/{id}/encaissements")
    public List<EncaissementResponse> getEncaissements(@PathVariable Long id) {
        LigneRecette ligne = getLignesRecetteUseCase.findById(id);
        return mapper.toEncaissementResponseList(ligne.getEncaissements());
    }

    @PatchMapping("/{id}/annuler")
    public LigneRecetteResponse annuler(@PathVariable Long id,
                                        @Valid @RequestBody AnnulationRequest request) {
        return mapper.toResponse(annulerLigneRecetteUseCase.executer(id, request.motif()));
    }

    /**
     * Remet une ligne annulée en circulation : elle retrouve le statut que
     * dictent ses versements et redevient exigible. Refusé si la période est
     * clôturée.
     */
    @PatchMapping("/{id}/restaurer")
    public LigneRecetteResponse restaurer(@PathVariable Long id) {
        return mapper.toResponse(restaurerLigneRecetteUseCase.executer(id));
    }

    /**
     * Ce qu'il faut savoir avant de déplacer la recette : qui peut la reprendre, et
     * ce que le déplacement entraînera.
     *
     * <p>Le serveur juge chaque chauffeur — un candidat pris ailleurs ce jour-là
     * revient marqué non éligible, avec sa raison. L'écran montre ainsi le
     * conflit <b>avant</b> le choix, au lieu de laisser choisir puis refuser.
     */
    @GetMapping("/{id:\\d+}/chauffeurs-eligibles")
    public ApercuReaffectationResponse chauffeursEligibles(@PathVariable Long id) {
        return ApercuReaffectationResponse.de(getApercuReaffectationUseCase.pourRecette(id));
    }

    /**
     * Porte la recette au compte d'un autre chauffeur : la créance, ses
     * versements et la pénalité qu'elle a pu engendrer changent de débiteur.
     * Aucun montant ne bouge. Refusé si un arrêté l'a consignée, si les livres
     * du jour sont fermés, ou si le chauffeur visé conduisait ailleurs ce jour-là.
     */
    @PatchMapping("/{id}/chauffeur")
    public LigneRecetteResponse reaffecterChauffeur(
            @PathVariable Long id,
            @Valid @RequestBody ReaffectationChauffeurRequest request) {
        return mapper.toResponse(reaffecterChauffeurRecetteUseCase.executer(
                id, request.chauffeurId(), request.motif()));
    }

    @PatchMapping("/{id}/confirmer-versement")
    public LigneRecetteResponse confirmerVersement(@PathVariable Long id) {
        return mapper.toResponse(confirmerVersementUseCase.executer(id));
    }

    @PostMapping("/generer")
    @ResponseStatus(HttpStatus.CREATED)
    public List<LigneRecetteResponse> generer(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        // Principe : sans date, la génération concerne la veille (J-1).
        return mapper.toResponseList(genererLignesRecetteUseCase.executer(
                date != null ? date : LocalDate.now().minusDays(1)));
    }
}
