package com.tmk.vtcmanager.interfaces.rest.utilisateur;

import com.tmk.vtcmanager.application.exception.RoleInsufficientException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Le compte servi par les routes « /moi » vient du jeton, jamais du client :
 * ces cas verrouillent cette garantie.
 */
class CurrentUserResolverTest {

    private final CurrentUserResolver resolver = new CurrentUserResolver();

    @AfterEach
    void viderLeContexte() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void rend_le_sub_du_jeton() {
        poserJeton("6f0d-abcd");

        assertThat(resolver.idOrThrow()).isEqualTo("6f0d-abcd");
    }

    @Test
    void refuse_une_authentification_qui_n_est_pas_un_jeton() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("alice", "secret", List.of()));

        assertThatThrownBy(resolver::idOrThrow)
                .isInstanceOf(RoleInsufficientException.class);
    }

    @Test
    void refuse_un_contexte_vide() {
        assertThatThrownBy(resolver::idOrThrow)
                .isInstanceOf(RoleInsufficientException.class);
    }

    @Test
    void refuse_un_jeton_sans_sujet() {
        poserJeton(null);

        assertThatThrownBy(resolver::idOrThrow)
                .isInstanceOf(RoleInsufficientException.class);
    }

    private void poserJeton(String sujet) {
        Jwt.Builder builder = Jwt.withTokenValue("jeton")
                .header("alg", "none")
                .claim("preferred_username", "alice");
        if (sujet != null) {
            builder.subject(sujet);
        }
        Jwt jwt = builder.claims(claims -> claims.putIfAbsent("iss", "tests")).build();
        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(jwt, List.of(), "alice"));
    }
}
