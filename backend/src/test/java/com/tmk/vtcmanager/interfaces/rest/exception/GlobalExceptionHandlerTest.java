package com.tmk.vtcmanager.interfaces.rest.exception;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void routeInconnue_renvoie404() {
        var request = new MockHttpServletRequest("GET", "/v3/api-docs");

        var response = handler.handleGeneric(new NoResourceFoundException(HttpMethod.GET, "v3/api-docs"), request);

        assertThat(response.getStatusCode().value()).isEqualTo(404);
        assertThat(response.getBody().getMessage()).isEqualTo("Ressource introuvable.");
    }

    @Test
    void methodeNonSupportee_renvoie405() {
        var request = new MockHttpServletRequest("GET", "/api/auth/login");

        var response = handler.handleGeneric(new HttpRequestMethodNotSupportedException("GET"), request);

        assertThat(response.getStatusCode().value()).isEqualTo(405);
    }

    @Test
    void exceptionInattendue_resteUne500() {
        var request = new MockHttpServletRequest("GET", "/api/vehicules");

        var response = handler.handleGeneric(new RuntimeException("boom"), request);

        assertThat(response.getStatusCode().value()).isEqualTo(500);
    }
}
