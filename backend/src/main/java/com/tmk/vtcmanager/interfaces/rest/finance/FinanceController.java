package com.tmk.vtcmanager.interfaces.rest.finance;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.usecases.finance.CloturerPeriodeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.ExportComptableUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetBalanceAgeeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetBilanUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetCloturesPeriodeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetCompteResultatUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetCreancesChauffeurUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetMargesParVehiculeUseCase;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.BilanResponse;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.CloturePeriodeResponse;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.CompteResultatResponse;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.CreanceChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.LigneCreanceResponse;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.MargeVehiculeResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/finances")
@RequiredArgsConstructor
public class FinanceController {

    private final GetBalanceAgeeUseCase getBalanceAgeeUseCase;
    private final GetCreancesChauffeurUseCase getCreancesChauffeurUseCase;
    private final GetCompteResultatUseCase getCompteResultatUseCase;
    private final GetMargesParVehiculeUseCase getMargesParVehiculeUseCase;
    private final GetBilanUseCase getBilanUseCase;
    private final ExportComptableUseCase exportComptableUseCase;
    private final CloturerPeriodeUseCase cloturerPeriodeUseCase;
    private final GetCloturesPeriodeUseCase getCloturesPeriodeUseCase;

    @GetMapping("/balance-agee")
    public List<CreanceChauffeurResponse> getBalanceAgee() {
        return getBalanceAgeeUseCase.executer().stream()
                .map(c -> new CreanceChauffeurResponse(c.getChauffeurId(),
                        c.getChauffeurNom(), c.getChauffeurPrenom(), c.getNbLignes(),
                        c.getDu0a7Jours(), c.getDu8a30Jours(), c.getDuPlus30Jours(),
                        c.getTotal()))
                .toList();
    }

    @GetMapping("/balance-agee/{chauffeurId}")
    public List<LigneCreanceResponse> getCreancesChauffeur(@PathVariable Long chauffeurId) {
        return getCreancesChauffeurUseCase.executer(chauffeurId).stream()
                .map(l -> new LigneCreanceResponse(l.getDocument(), l.getDocumentId(),
                        l.getVehiculeId(), l.getDateReference(), l.getMontantDu(),
                        l.getMontantRegle(), l.getRestant()))
                .toList();
    }

    // ── Compte de résultat ───────────────────────────────────────────────

    @GetMapping("/compte-resultat")
    public CompteResultatResponse getCompteResultat(
            @RequestParam int annee,
            @RequestParam int mois,
            @RequestParam(defaultValue = "CAISSE") BaseComptable base) {
        CompteResultat cr = getCompteResultatUseCase.executer(annee, mois, base);
        return new CompteResultatResponse(cr.getAnnee(), cr.getMois(), cr.getBase().name(),
                cr.getProduitsExploitation(), cr.getChargesVariables(),
                cr.getMargeSurCoutsVariables(), cr.getChargesFixes(),
                cr.getExcedentBrutExploitation(), cr.getAmortissements(),
                cr.getResultatGestion(), cr.getPontCreances());
    }

    @GetMapping("/compte-resultat/par-vehicule")
    public List<MargeVehiculeResponse> getMargesParVehicule(
            @RequestParam int annee, @RequestParam int mois) {
        return getMargesParVehiculeUseCase.executer(annee, mois).stream()
                .map(m -> new MargeVehiculeResponse(m.getVehiculeId(), m.getImmatriculation(),
                        m.getProduits(), m.getChargesVariables(), m.getMarge()))
                .toList();
    }

    // ── Bilan de gestion ─────────────────────────────────────────────────

    @GetMapping("/bilan")
    public BilanResponse getBilan() {
        var bilan = getBilanUseCase.executer();
        return new BilanResponse(bilan.getDate(), bilan.getTresorerie(),
                bilan.getCreancesChauffeurs(), bilan.getImmobilisationsNettes(),
                bilan.getTotalActif(), bilan.getDetteEtatContraventions(),
                bilan.getSituationNette());
    }

    // ── Export comptable ─────────────────────────────────────────────────

    @GetMapping("/export-comptable")
    public ResponseEntity<byte[]> exportComptable(@RequestParam int annee, @RequestParam int mois) {
        String csv = exportComptableUseCase.executer(annee, mois);
        String nomFichier = String.format("journal_%d_%02d.csv", annee, mois);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=" + nomFichier)
                .contentType(MediaType.parseMediaType("text/csv;charset=UTF-8"))
                .body(csv.getBytes(StandardCharsets.UTF_8));
    }

    // ── Clôture de période ───────────────────────────────────────────────

    @PostMapping("/clotures-periode")
    @ResponseStatus(HttpStatus.CREATED)
    public CloturePeriodeResponse cloturerPeriode(@RequestBody Map<String, Integer> body) {
        var cloture = cloturerPeriodeUseCase.executer(body.get("annee"), body.get("mois"));
        return new CloturePeriodeResponse(cloture.getId(), cloture.getAnnee(),
                cloture.getMois(), cloture.getDateCloture());
    }

    @GetMapping("/clotures-periode")
    public List<CloturePeriodeResponse> getCloturesPeriode() {
        return getCloturesPeriodeUseCase.executer().stream()
                .map(c -> new CloturePeriodeResponse(c.getId(), c.getAnnee(), c.getMois(),
                        c.getDateCloture()))
                .toList();
    }
}
