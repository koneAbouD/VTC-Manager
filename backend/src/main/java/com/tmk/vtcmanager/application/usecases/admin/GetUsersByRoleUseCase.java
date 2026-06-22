package com.tmk.vtcmanager.application.usecases.admin;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetUsersByRoleUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public List<UserInfo> execute(String roleName) {
        return keycloakAdminPort.getUsersByRole(roleName);
    }
}