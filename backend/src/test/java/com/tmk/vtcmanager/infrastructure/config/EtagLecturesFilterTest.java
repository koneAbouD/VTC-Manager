package com.tmk.vtcmanager.infrastructure.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Une application qui détient déjà la réponse ne la retélécharge pas : 304
 * sans corps quand rien n'a changé.
 */
@DisplayName("ETag sur les lectures de l'API")
class EtagLecturesFilterTest {

    private final EtagLecturesFilter filter = new EtagLecturesFilter();

    /** Réponse du contrôleur, avec l'en-tête qu'y pose Spring Security. */
    private static FilterChain controleur(String corps) {
        return (req, res) -> {
            HttpServletResponse http = (HttpServletResponse) res;
            http.setHeader("Cache-Control", "no-cache, no-store, max-age=0, must-revalidate");
            http.setContentType("application/json");
            http.getOutputStream().write(corps.getBytes(StandardCharsets.UTF_8));
        };
    }

    private MockHttpServletResponse executer(String methode, String ifNoneMatch, String corps)
            throws Exception {
        MockHttpServletRequest requete = new MockHttpServletRequest(methode, "/api/vehicules");
        if (ifNoneMatch != null) requete.addHeader("If-None-Match", ifNoneMatch);
        MockHttpServletResponse reponse = new MockHttpServletResponse();
        filter.doFilter(requete, reponse, controleur(corps));
        return reponse;
    }

    @Test
    @DisplayName("une lecture porte un ETag faible, malgré le no-store de Spring Security")
    void lectureAvecEtag() throws Exception {
        MockHttpServletResponse reponse = executer("GET", null, "[{\"id\":1}]");

        assertThat(reponse.getStatus()).isEqualTo(200);
        assertThat(reponse.getHeader("ETag")).startsWith("W/\"");
        assertThat(reponse.getContentAsString()).isEqualTo("[{\"id\":1}]");
        assertThat(reponse.getHeader("Cache-Control")).contains("no-store");
    }

    @Test
    @DisplayName("rien n'a changé : 304 sans corps")
    void inchangeEst304() throws Exception {
        String etag = executer("GET", null, "[{\"id\":1}]").getHeader("ETag");

        MockHttpServletResponse reponse = executer("GET", etag, "[{\"id\":1}]");

        assertThat(reponse.getStatus()).isEqualTo(304);
        assertThat(reponse.getContentAsByteArray()).isEmpty();
    }

    @Test
    @DisplayName("la donnée a changé : réponse complète et nouvel ETag")
    void modifieEst200() throws Exception {
        String etag = executer("GET", null, "[{\"id\":1}]").getHeader("ETag");

        MockHttpServletResponse reponse = executer("GET", etag, "[{\"id\":1},{\"id\":2}]");

        assertThat(reponse.getStatus()).isEqualTo(200);
        assertThat(reponse.getHeader("ETag")).isNotEqualTo(etag);
        assertThat(reponse.getContentAsString()).isEqualTo("[{\"id\":1},{\"id\":2}]");
    }

    @Test
    @DisplayName("une écriture n'est jamais revalidée")
    void ecritureSansEtag() throws Exception {
        MockHttpServletResponse reponse = executer("POST", null, "{\"id\":9}");

        assertThat(reponse.getHeader("ETag")).isNull();
    }
}
