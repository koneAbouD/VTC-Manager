package com.tmk.vtcmanager.application.usecases.admin;

import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllRealmRolesUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public List<String> execute() {
        return keycloakAdminPort.getAllRealmRoles();
    }
}
