package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

/**
 * Solde théorique d'un compte arrêté à une date.
 *
 * <p>Sert au comptage antidaté : la clôture de caisse compare le comptage au
 * solde <em>de la journée comptée</em>, pas au solde courant. Sans cette
 * lecture, l'écran afficherait un écart et le serveur en calculerait un autre.
 */
@RequiredArgsConstructor
public class GetSoldeCompteALaDateUseCase {

    private final CompteTresorerieRepository compteTresorerieRepository;

    @Transactional(readOnly = true)
    public CompteAvecSolde executer(Long compteId, LocalDate date) {
        return compteTresorerieRepository
                .findAvecSoldeALaDate(compteId, date != null ? date : LocalDate.now())
                .orElseThrow(() -> new CompteTresorerieNotFoundException(compteId));
    }
}
