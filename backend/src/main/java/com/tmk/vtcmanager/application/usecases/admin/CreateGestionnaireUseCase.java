package com.tmk.vtcmanager.application.usecases.admin;

import com.tmk.vtcmanager.application.domain.auth.RegisterRequest;
import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CreateGestionnaireUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public UserInfo execute(RegisterRequest request) {
        return keycloakAdminPort.createUser(
                RegisterRequest.builder()
                        .username(request.getUsername())
                        .email(request.getEmail())
                        .password(request.getPassword())
                        .firstName(request.getFirstName())
                        .lastName(request.getLastName())
                        .roles(List.of("GESTIONNAIRE"))
                        .build()
        );
    }
}