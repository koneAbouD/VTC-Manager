package com.tmk.vtcmanager.interfaces.rest.cotisation.mapper;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.encaissement.MontantParLigne;
import com.tmk.vtcmanager.application.domain.encaissement.ResultatEncaissementLot;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.request.EncaissementCotisationLotRequest;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.request.EncaissementCotisationRequest;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.EncaissementCotisationLotResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.EncaissementCotisationResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.LigneCotisationResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.math.BigDecimal;
import java.util.List;

@Mapper(componentModel = "spring")
public interface CotisationRestMapper {

    @Mapping(target = "id",                  ignore = true)
    @Mapping(target = "ligneCotisationId",    ignore = true)
    @Mapping(target = "operationFinanciereId", ignore = true)
    @Mapping(target = "motifAnnulation",      ignore = true)
    @Mapping(target = "annulePar",            ignore = true)
    @Mapping(target = "annuleLe",             ignore = true)
    EncaissementCotisation toDomain(EncaissementCotisationRequest request);

    EncaissementCotisationResponse toResponse(EncaissementCotisation encaissement);

    List<EncaissementCotisationResponse> toEncaissementResponseList(List<EncaissementCotisation> list);

    @Mapping(target = "montantRestant", expression = "java(computeRestant(ligne))")
    LigneCotisationResponse toResponse(LigneCotisation ligne);

    List<LigneCotisationResponse> toResponseList(List<LigneCotisation> lignes);

    // ── Encaissement de masse ────────────────────────────────────────────

    List<MontantParLigne> toMontants(
            List<EncaissementCotisationLotRequest.LigneMontantRequest> lignes);

    EncaissementCotisationLotResponse.ResultatLigneResponse toResponse(
            ResultatEncaissementLot resultat);

    List<EncaissementCotisationLotResponse.ResultatLigneResponse> toResultatList(
            List<ResultatEncaissementLot> resultats);

    /** Compte les verdicts au passage : l'écran affiche « n encaissées, m en échec ». */
    default EncaissementCotisationLotResponse toLotResponse(
            List<ResultatEncaissementLot> resultats) {
        int reussis = (int) resultats.stream().filter(ResultatEncaissementLot::succes).count();
        return new EncaissementCotisationLotResponse(reussis, resultats.size() - reussis,
                toResultatList(resultats));
    }

    default BigDecimal computeRestant(LigneCotisation ligne) {
        BigDecimal encaisse = ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
        return ligne.getMontantDu().subtract(encaisse).max(BigDecimal.ZERO);
    }
}
