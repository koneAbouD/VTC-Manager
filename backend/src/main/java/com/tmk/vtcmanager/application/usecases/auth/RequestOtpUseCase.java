package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.domain.auth.OtpCode;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.common.PhoneNumberNormalizer;
import com.tmk.vtcmanager.application.domain.common.SecretGenerator;
import com.tmk.vtcmanager.application.ports.auth.OtpDeliveryPort;
import com.tmk.vtcmanager.application.ports.auth.OtpHashPort;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.OtpCodeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDateTime;
import java.util.Optional;

/**
 * Demande d'un code OTP pour l'app chauffeur.
 *
 * Sécurité :
 *  - anti-énumération : la réponse est toujours neutre, qu'un chauffeur existe ou non ;
 *  - rate-limiting : nombre d'envois plafonné par heure et par numéro ;
 *  - le code n'est envoyé que si un chauffeur actif possède déjà un compte (keycloakUserId).
 */
@Slf4j
@RequiredArgsConstructor
public class RequestOtpUseCase {

    private static final int LONGUEUR_CODE = 6;
    private static final int TTL_MINUTES = 5;
    private static final int MAX_ENVOIS_PAR_HEURE = 5;

    private final ChauffeurRepository chauffeurRepository;
    private final OtpCodeRepository otpCodeRepository;
    private final OtpHashPort otpHashPort;
    private final OtpDeliveryPort otpDeliveryPort;

    public void execute(String telephoneSaisi) {
        String telephone = PhoneNumberNormalizer.canonique(telephoneSaisi);
        if (telephone.isBlank()) {
            return; // saisie vide : réponse neutre
        }

        // Rate-limiting (appliqué même en l'absence de chauffeur pour ne pas divulguer d'info)
        long envoisRecents = otpCodeRepository.countEmisDepuis(telephone, LocalDateTime.now().minusHours(1));
        if (envoisRecents >= MAX_ENVOIS_PAR_HEURE) {
            throw new IllegalStateException(
                    "Trop de demandes de code. Veuillez réessayer dans quelques minutes.");
        }

        Optional<Chauffeur> chauffeurOpt = chauffeurRepository.findByTelephone(telephone);
        if (chauffeurOpt.isEmpty() || !estEligible(chauffeurOpt.get())) {
            // Réponse neutre : on ne révèle pas l'absence de compte.
            log.info("Demande OTP pour un numéro sans compte chauffeur éligible : {}", telephone);
            return;
        }

        String code = SecretGenerator.codeNumerique(LONGUEUR_CODE);

        otpCodeRepository.invaliderTousLesActifs(telephone);
        otpCodeRepository.save(OtpCode.builder()
                .telephone(telephone)
                .codeHash(otpHashPort.hash(code))
                .expiresAt(LocalDateTime.now().plusMinutes(TTL_MINUTES))
                .tentatives(0)
                .consomme(false)
                .createdAt(LocalDateTime.now())
                .build());

        otpDeliveryPort.envoyer(telephone, code);
    }

    private boolean estEligible(Chauffeur chauffeur) {
        return chauffeur.getKeycloakUserId() != null
                && chauffeur.getStatutManuel() != ChauffeurStatus.INACTIF
                && chauffeur.getStatutManuel() != ChauffeurStatus.SUSPENDU;
    }
}
