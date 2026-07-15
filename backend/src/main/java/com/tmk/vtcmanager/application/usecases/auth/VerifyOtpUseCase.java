package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.domain.auth.OtpCode;
import com.tmk.vtcmanager.application.domain.auth.TokenResponse;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.common.PhoneNumberNormalizer;
import com.tmk.vtcmanager.application.exception.OtpInvalidException;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAuthPort;
import com.tmk.vtcmanager.application.ports.auth.OtpHashPort;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.OtpCodeRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDateTime;

/**
 * Vérifie un code OTP et, en cas de succès, émet des tokens Keycloak.
 *
 * L'émission des tokens se fait par <b>token exchange</b> (impersonation) : le
 * mot de passe du chauffeur n'est jamais touché, ce qui permet la coexistence
 * de l'auth OTP et de l'auth par mot de passe sur le même compte.
 */
@RequiredArgsConstructor
public class VerifyOtpUseCase {

    private static final int MAX_TENTATIVES = 5;

    private final ChauffeurRepository chauffeurRepository;
    private final OtpCodeRepository otpCodeRepository;
    private final OtpHashPort otpHashPort;
    private final KeycloakAuthPort keycloakAuthPort;

    public TokenResponse execute(String telephoneSaisi, String code) {
        String telephone = PhoneNumberNormalizer.canonique(telephoneSaisi);

        OtpCode otp = otpCodeRepository.findDernierActif(telephone)
                .orElseThrow(() -> new OtpInvalidException("Code invalide ou expiré."));

        LocalDateTime maintenant = LocalDateTime.now();
        if (!otp.estUtilisable(maintenant, MAX_TENTATIVES)) {
            throw new OtpInvalidException("Code invalide ou expiré. Demandez un nouveau code.");
        }

        if (!otpHashPort.matches(code, otp.getCodeHash())) {
            otp.setTentatives(otp.getTentatives() + 1);
            otpCodeRepository.save(otp);
            throw new OtpInvalidException("Code incorrect.");
        }

        // Succès : consommer le code.
        otp.setConsomme(true);
        otpCodeRepository.save(otp);

        Chauffeur chauffeur = chauffeurRepository.findByTelephone(telephone)
                .filter(c -> c.getKeycloakUserId() != null)
                .orElseThrow(() -> new OtpInvalidException("Aucun compte associé à ce numéro."));

        // Émission des tokens sans toucher au mot de passe (token exchange).
        return keycloakAuthPort.exchangeToken(chauffeur.getKeycloakUserId());
    }
}
