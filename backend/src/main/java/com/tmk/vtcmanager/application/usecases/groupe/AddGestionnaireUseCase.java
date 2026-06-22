package com.tmk.vtcmanager.application.usecases.groupe;

import com.tmk.vtcmanager.application.domain.groupe.GestionnaireGroupe;
import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.RoleInsufficientException;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AddGestionnaireUseCase {

    static final String ROLE_GESTIONNAIRE = "GESTIONNAIRE";

    private final GroupeVehiculeRepository groupeVehiculeRepository;
    private final KeycloakAdminPort keycloakAdminPort;

    public GroupeVehicule execute(Long groupeId, GestionnaireGroupe gestionnaire) {
        verifierRoleGestionnaire(gestionnaire.getUserId());

        GroupeVehicule groupe = groupeVehiculeRepository.findById(groupeId)
                .orElseThrow(() -> ResourceNotFoundException.of("Groupe", groupeId));

        groupe.setGestionnaire(gestionnaire);
        return groupeVehiculeRepository.save(groupe);
    }

    private void verifierRoleGestionnaire(String userId) {
        boolean hasRole = keycloakAdminPort.getUserRoles(userId).stream()
                .anyMatch(ROLE_GESTIONNAIRE::equalsIgnoreCase);
        if (!hasRole) {
            throw new RoleInsufficientException(userId, ROLE_GESTIONNAIRE);
        }
    }
}