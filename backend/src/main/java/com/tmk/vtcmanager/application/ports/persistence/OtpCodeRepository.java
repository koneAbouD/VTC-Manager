package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.auth.OtpCode;

import java.time.LocalDateTime;
import java.util.Optional;

public interface OtpCodeRepository {

    OtpCode save(OtpCode otpCode);

    /** Dernier code non consommé pour ce téléphone (le plus récemment créé). */
    Optional<OtpCode> findDernierActif(String telephone);

    /** Nombre de codes émis pour ce téléphone depuis {@code depuis} (rate-limiting). */
    long countEmisDepuis(String telephone, LocalDateTime depuis);

    /** Invalide (consomme) tous les codes actifs restants d'un téléphone. */
    void invaliderTousLesActifs(String telephone);
}
