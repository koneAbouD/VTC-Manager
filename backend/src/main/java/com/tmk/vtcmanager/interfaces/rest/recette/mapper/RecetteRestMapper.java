package com.tmk.vtcmanager.interfaces.rest.recette.mapper;

import com.tmk.vtcmanager.application.domain.encaissement.MontantParLigne;
import com.tmk.vtcmanager.application.domain.encaissement.ResultatEncaissementLot;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.request.EncaissementLotRequest;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.request.EncaissementRequest;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.EncaissementLotResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.EncaissementResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.LigneRecetteResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.math.BigDecimal;
import java.util.List;

@Mapper(componentModel = "spring")
public interface RecetteRestMapper {

    @Mapping(target = "id",                  ignore = true)
    @Mapping(target = "ligneRecetteId",      ignore = true)
    @Mapping(target = "operationFinanciereId", ignore = true)
    @Mapping(target = "motifAnnulation",     ignore = true)
    @Mapping(target = "annulePar",           ignore = true)
    @Mapping(target = "annuleLe",            ignore = true)
    Encaissement toDomain(EncaissementRequest request);

    EncaissementResponse toResponse(Encaissement encaissement);

    List<EncaissementResponse> toEncaissementResponseList(List<Encaissement> encaissements);

    @Mapping(target = "montantRestant", expression = "java(computeMontantRestant(ligne))")
    @Mapping(target = "encaissements", source = "encaissements")
    LigneRecetteResponse toResponse(LigneRecette ligne);

    List<LigneRecetteResponse> toResponseList(List<LigneRecette> lignes);

    // ── Encaissement de masse ────────────────────────────────────────────

    List<MontantParLigne> toMontants(List<EncaissementLotRequest.LigneMontantRequest> lignes);

    EncaissementLotResponse.ResultatLigneResponse toResponse(ResultatEncaissementLot resultat);

    List<EncaissementLotResponse.ResultatLigneResponse> toResultatList(
            List<ResultatEncaissementLot> resultats);

    /** Compte les verdicts au passage : l'écran affiche « n encaissées, m en échec ». */
    default EncaissementLotResponse toLotResponse(List<ResultatEncaissementLot> resultats) {
        int reussis = (int) resultats.stream().filter(ResultatEncaissementLot::succes).count();
        return new EncaissementLotResponse(reussis, resultats.size() - reussis,
                toResultatList(resultats));
    }

    default BigDecimal computeMontantRestant(LigneRecette ligne) {
        if (ligne.getMontantAttendu() == null) return null;
        BigDecimal encaisse = ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
        return ligne.getMontantAttendu().subtract(encaisse).max(BigDecimal.ZERO);
    }
}
