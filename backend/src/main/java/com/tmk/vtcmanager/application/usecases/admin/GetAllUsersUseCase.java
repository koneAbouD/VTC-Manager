package com.tmk.vtcmanager.application.usecases.admin;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllUsersUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public List<UserInfo> execute() {
        return keycloakAdminPort.getAllUsers();
    }
}
