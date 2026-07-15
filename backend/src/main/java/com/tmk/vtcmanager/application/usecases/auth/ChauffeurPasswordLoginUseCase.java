package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.domain.auth.TokenResponse;
import com.tmk.vtcmanager.application.domain.common.JwtPayloadReader;
import com.tmk.vtcmanager.application.domain.common.PhoneNumberNormalizer;
import com.tmk.vtcmanager.application.exception.RoleInsufficientException;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAuthPort;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Connexion d'un chauffeur par identifiant + mot de passe.
 *
 * L'identifiant est le numéro de téléphone (username Keycloak = téléphone
 * canonique). On normalise les saisies numériques ; les autres identifiants
 * (email/username) sont transmis tels quels. On vérifie enfin que le compte
 * correspond bien à un chauffeur, pour renvoyer une erreur claire sinon.
 */
@Slf4j
@RequiredArgsConstructor
public class ChauffeurPasswordLoginUseCase {

    private final KeycloakAuthPort keycloakAuthPort;
    private final ChauffeurRepository chauffeurRepository;

    public TokenResponse execute(String identifiant, String motDePasse) {
        String username = normaliser(identifiant);
        TokenResponse tokens = keycloakAuthPort.login(username, motDePasse);

        // Vérifie que le token correspond bien à un chauffeur enrôlé.
        // On accepte le lien Keycloak (sub) OU une correspondance par téléphone
        // (l'identifiant EST le numéro), pour être robuste si le lien DB n'est
        // pas encore posé ou si le sub n'est pas exploitable.
        String sub = JwtPayloadReader.sub(tokens.getAccessToken());
        boolean parSub = sub != null
                && chauffeurRepository.findByKeycloakUserId(sub).isPresent();
        boolean parTelephone = chauffeurRepository.findByTelephone(username).isPresent();
        if (!parSub && !parTelephone) {
            log.warn("Login chauffeur refusé pour '{}' : aucun chauffeur lié (sub={}, parTelephone=false)",
                    username, sub);
            throw new RoleInsufficientException(username, "CHAUFFEUR");
        }
        return tokens;
    }

    /** Un identifiant purement téléphonique est canonicalisé ; sinon inchangé. */
    private String normaliser(String identifiant) {
        String saisie = identifiant == null ? "" : identifiant.trim();
        boolean telephone = !saisie.isEmpty() && saisie.matches("[0-9+ ]+");
        return telephone ? PhoneNumberNormalizer.canonique(saisie) : saisie;
    }
}
