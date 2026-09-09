package com.tmk.vtcmanager.interfaces.rest.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.usecases.cotisation.AnnulerLigneCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.ReaffecterChauffeurCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.RestaurerLigneCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.reaffectation.GetApercuReaffectationUseCase;
import com.tmk.vtcmanager.application.services.ModificationDateEncaissementService;
import com.tmk.vtcmanager.application.services.ReaffectationChauffeurService;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import com.tmk.vtcmanager.application.usecases.cotisation.CreateEncaissementCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.CreateEncaissementsCotisationLotUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.GenererLignesCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.GetLignesCotisationUseCase;
import com.tmk.vtcmanager.application.usecases.cotisation.ModifierDateEncaissementCotisationUseCase;
import com.tmk.vtcmanager.interfaces.rest.common.AnnulationRequest;
import com.tmk.vtcmanager.interfaces.rest.common.ModificationDateEncaissementRequest;
import com.tmk.vtcmanager.interfaces.rest.common.ReaffectationChauffeurRequest;
import com.tmk.vtcmanager.interfaces.rest.reaffectation.dto.ApercuReaffectationResponse;
import com.tmk.vtcmanager.interfaces.rest.common.PageResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.request.EncaissementCotisationLotRequest;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.request.EncaissementCotisationRequest;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.EncaissementCotisationLotResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.EncaissementCotisationResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.LigneCotisationResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.TotauxCotisationResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.mapper.CotisationRestMapper;
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
@RequestMapping("/api/cotisations/lignes")
@RequiredArgsConstructor
public class LigneCotisationController {

    private final GetLignesCotisationUseCase getLignesCotisationUseCase;
    private final CreateEncaissementCotisationUseCase createEncaissementUseCase;
    private final CreateEncaissementsCotisationLotUseCase createEncaissementsLotUseCase;
    private final AnnulerLigneCotisationUseCase annulerUseCase;
    private final RestaurerLigneCotisationUseCase restaurerUseCase;
    private final ReaffecterChauffeurCotisationUseCase reaffecterChauffeurUseCase;
    private final ModifierDateEncaissementCotisationUseCase modifierDateEncaissementUseCase;
    private final VerrouArreteService verrouArreteService;
    private final ReaffectationChauffeurService reaffectationChauffeurService;
    private final ModificationDateEncaissementService modificationDateEncaissementService;
    private final GetApercuReaffectationUseCase getApercuReaffectationUseCase;
    private final GenererLignesCotisationUseCase genererUseCase;
    private final CotisationRestMapper mapper;

    @GetMapping
    public List<LigneCotisationResponse> getLignes(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) StatutLigneCotisation statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin) {
        return mapper.toResponseList(getLignesCotisationUseCase.findByCriteres(
                LigneCotisationFiltres.builder()
                        .vehiculeId(vehiculeId).chauffeurId(chauffeurId)
                        .statut(statut).dateDebut(dateDebut).dateFin(dateFin)
                        .build()));
    }

    @GetMapping("/page")
    public PageResponse<LigneCotisationResponse> getLignesPage(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) StatutLigneCotisation statut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin,
            @RequestParam(required = false) String recherche,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var result = getLignesCotisationUseCase.findPageByCriteres(
                LigneCotisationFiltres.builder()
                        .vehiculeId(vehiculeId).chauffeurId(chauffeurId)
                        .statut(statut).dateDebut(dateDebut).dateFin(dateFin)
                        .recherche(recherche)
                        .build(),
                page, size).map(mapper::toResponse);
        return PageResponse.from(result);
    }

    /**
     * Cumuls de la sélection courante, tous statuts confondus.
     *
     * <p>Le paramètre {@code statut} est volontairement absent : ces compteurs
     * servent justement à choisir un statut, et les filtrer dessus mettrait
     * toutes les autres pastilles à zéro.</p>
     */
    @GetMapping("/totaux")
    public TotauxCotisationResponse getTotaux(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long chauffeurId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateDebut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFin,
            @RequestParam(required = false) String recherche) {
        return TotauxCotisationResponse.from(getLignesCotisationUseCase.totauxParStatut(
                LigneCotisationFiltres.builder()
                        .vehiculeId(vehiculeId).chauffeurId(chauffeurId)
                        .dateDebut(dateDebut).dateFin(dateFin)
                        .recherche(recherche)
                        .build()));
    }

    @GetMapping("/{id:\\d+}")
    public LigneCotisationResponse getLigneById(@PathVariable Long id) {
        return mapper.toResponse(enrichir(getLignesCotisationUseCase.findById(id)));
    }

    /**
     * Ce que la fiche a le droit de proposer, en un seul endroit : chaque action
     * dit au client si elle est encore ouverte, plutôt que de le laisser tenter
     * puis échouer.
     */
    private LigneCotisation enrichir(LigneCotisation ligne) {
        // « Restaurer » a-t-il encore un sens : un arrêté — période close,
        // caisse comptée — peut l'avoir fermée depuis.
        ligne.setRestaurable(verrouArreteService.estRestaurable(ligne.getDateCotisation()));
        // Le titulaire du dépôt peut-il encore changer.
        String blocage = reaffectationChauffeurService.motifBlocage(ligne);
        ligne.setReaffectable(blocage == null);
        ligne.setMotifNonReaffectable(blocage);
        // Et, versement par versement, si sa date reste corrigeable.
        modificationDateEncaissementService.marquerVersements(ligne);
        return ligne;
    }

    @PostMapping("/{id}/encaissements")
    @ResponseStatus(HttpStatus.CREATED)
    public EncaissementCotisationResponse createEncaissement(
            @PathVariable Long id,
            @Valid @RequestBody EncaissementCotisationRequest request) {
        return mapper.toResponse(createEncaissementUseCase.executer(id, mapper.toDomain(request)));
    }

    /**
     * Encaissement de masse : un versement du chauffeur solde plusieurs
     * cotisations d'un coup, avec un montant propre à chaque ligne.
     *
     * <p>Toujours 200, même si tout a été refusé : le lot n'est pas un tout ou
     * rien, et c'est le détail de la réponse qui porte le verdict de chaque
     * ligne — motif compris, rédigé pour être affiché tel quel.
     */
    @PostMapping("/encaissements-lot")
    public EncaissementCotisationLotResponse createEncaissementsLot(
            @Valid @RequestBody EncaissementCotisationLotRequest request) {
        return mapper.toLotResponse(createEncaissementsLotUseCase.executer(
                mapper.toMontants(request.lignes()),
                request.modeEncaissement(),
                request.dateEncaissement(),
                request.reference(),
                request.commentaire()));
    }

    @GetMapping("/{id}/encaissements")
    public List<EncaissementCotisationResponse> getEncaissements(@PathVariable Long id) {
        return mapper.toEncaissementResponseList(getLignesCotisationUseCase.findById(id).getEncaissements());
    }

    /**
     * Corrige le jour d'un versement déjà enregistré : l'encaissement et
     * l'écriture qu'il a produite au journal changent de date ensemble. Aucun
     * montant ne bouge — le fonds détenu à date, le résultat du mois et le
     * décompte d'un futur arrêté suivent d'eux-mêmes. Refusé si un arrêté a
     * déjà rendu tout ou partie du dépôt, si la période est close, si la caisse
     * a été comptée à l'une des deux dates, ou si le versement a été extourné.
     */
    @PatchMapping("/{id}/encaissements/{encaissementId}/date")
    public LigneCotisationResponse modifierDateEncaissement(
            @PathVariable Long id,
            @PathVariable Long encaissementId,
            @Valid @RequestBody ModificationDateEncaissementRequest request) {
        return mapper.toResponse(enrichir(modifierDateEncaissementUseCase.executer(
                id, encaissementId, request.dateEncaissement())));
    }

    @PatchMapping("/{id}/annuler")
    public LigneCotisationResponse annuler(@PathVariable Long id,
                                           @Valid @RequestBody AnnulationRequest request) {
        return mapper.toResponse(annulerUseCase.executer(id, request.motif()));
    }

    /**
     * Remet une ligne annulée en circulation : elle retrouve le statut que
     * dictent ses versements et redevient due. Refusé si la période est
     * clôturée.
     */
    @PatchMapping("/{id}/restaurer")
    public LigneCotisationResponse restaurer(@PathVariable Long id) {
        return mapper.toResponse(restaurerUseCase.executer(id));
    }

    /**
     * Ce qu'il faut savoir avant de déplacer la cotisation : qui peut la reprendre, et
     * ce que le déplacement entraînera.
     *
     * <p>Le serveur juge chaque chauffeur — un candidat pris ailleurs ce jour-là
     * revient marqué non éligible, avec sa raison. L'écran montre ainsi le
     * conflit <b>avant</b> le choix, au lieu de laisser choisir puis refuser.
     */
    @GetMapping("/{id:\\d+}/chauffeurs-eligibles")
    public ApercuReaffectationResponse chauffeursEligibles(@PathVariable Long id) {
        return ApercuReaffectationResponse.de(getApercuReaffectationUseCase.pourCotisation(id));
    }

    /**
     * Porte la cotisation au compte d'un autre chauffeur : le dépôt et ses
     * versements changent de titulaire, sans qu'aucun montant ne bouge. Refusé
     * si un arrêté a déjà rendu tout ou partie du fonds, si les livres du jour
     * sont fermés, ou si le chauffeur visé conduisait ailleurs ce jour-là.
     */
    @PatchMapping("/{id}/chauffeur")
    public LigneCotisationResponse reaffecterChauffeur(
            @PathVariable Long id,
            @Valid @RequestBody ReaffectationChauffeurRequest request) {
        return mapper.toResponse(reaffecterChauffeurUseCase.executer(
                id, request.chauffeurId(), request.motif()));
    }

    @PostMapping("/generer")
    @ResponseStatus(HttpStatus.CREATED)
    public List<LigneCotisationResponse> generer(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        // Principe : sans date, la génération concerne la veille (J-1).
        return mapper.toResponseList(genererUseCase.executer(
                date != null ? date : LocalDate.now().minusDays(1)));
    }
}
