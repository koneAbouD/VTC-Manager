package com.tmk.vtcmanager.interfaces.rest.parametrage;

import com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ReferentielDescriptorResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Meta-catalogue des données de référence paramétrables.
 *
 * <p>Point d'entrée unique du module de paramétrage : le front récupère ici la
 * liste des référentiels et leur schéma, puis rend un écran générique (liste +
 * formulaire) piloté par cette description. Endpoint en lecture, ouvert à tout
 * utilisateur authentifié ; les mutations sont sur chaque référentiel et
 * réservées au rôle ADMIN.</p>
 */
@RestController
@RequestMapping("/api/v1/parametrage")
@RequiredArgsConstructor
@Tag(name = "Paramétrage", description = "Meta-catalogue des données de référence paramétrables")
public class ReferentielCatalogController {

    private final ReferentielCatalogue catalogue;

    @GetMapping("/catalogue")
    @Operation(summary = "Catalogue des référentiels paramétrables",
            description = "Retourne la description de chaque référentiel (clé, endpoint, éditable, schéma des "
                    + "champs). Le front construit dynamiquement l'écran de paramétrage à partir de ces "
                    + "métadonnées, sans page codée en dur.")
    public ResponseEntity<List<ReferentielDescriptorResponse>> catalogue() {
        return ResponseEntity.ok(catalogue.descripteurs());
    }
}
