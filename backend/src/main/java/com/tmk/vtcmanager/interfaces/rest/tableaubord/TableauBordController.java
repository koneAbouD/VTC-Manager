package com.tmk.vtcmanager.interfaces.rest.tableaubord;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.usecases.tableaubord.GetTableauBordUseCase;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.TableauBordResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.YearMonth;

/**
 * Tableau de bord de supervision : une lecture unique de la période, servie en
 * un appel pour que les quatre blocs de l'écran parlent du même instant.
 */
@RestController
@RequestMapping("/api/tableau-bord")
@RequiredArgsConstructor
public class TableauBordController {

    private final GetTableauBordUseCase getTableauBordUseCase;

    /**
     * @param base CAISSE (ce qui est entré et sorti) ou ENGAGEMENT (ce qui est
     *             dû) — même choix que le compte de résultat, dont le tableau
     *             de bord n'est qu'une lecture condensée.
     */
    @GetMapping
    public TableauBordResponse tableauBord(
            @RequestParam(required = false) Integer annee,
            @RequestParam(required = false) Integer mois,
            @RequestParam(defaultValue = "CAISSE") BaseComptable base,
            @RequestParam(required = false) Long groupeId,
            @RequestParam(required = false) Long activiteId) {
        YearMonth periode = (annee == null || mois == null)
                ? YearMonth.now()
                : YearMonth.of(annee, mois);
        return getTableauBordUseCase.executer(periode.getYear(), periode.getMonthValue(),
                base, groupeId, activiteId);
    }
}
