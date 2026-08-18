package com.tmk.vtcmanager.application.domain.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserInfo {
    private String id;
    private String username;
    private String email;
    private String firstName;
    private String lastName;
    /** Téléphone, stocké côté Keycloak dans l'attribut {@code phoneNumber}. */
    private String phone;
    private boolean enabled;
    private List<String> roles;
}
