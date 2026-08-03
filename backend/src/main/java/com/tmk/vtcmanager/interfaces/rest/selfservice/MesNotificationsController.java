package com.tmk.vtcmanager.interfaces.rest.selfservice;

import com.tmk.vtcmanager.application.domain.notification.ApplicationCliente;
import com.tmk.vtcmanager.interfaces.rest.notification.NotificationApiSupport;
import com.tmk.vtcmanager.interfaces.rest.notification.dto.request.DeviceTokenRequest;
import com.tmk.vtcmanager.interfaces.rest.notification.dto.response.CentreNotificationsResponse;
import com.tmk.vtcmanager.interfaces.rest.notification.dto.response.NotificationResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Notifications de l'espace chauffeur. Sous {@code /api/me}, donc réservé au
 * rôle CHAUFFEUR par la configuration de sécurité, et rattaché au compte du
 * jeton comme le reste du self-service.
 */
@RestController
@RequestMapping("/api/me")
@RequiredArgsConstructor
public class MesNotificationsController {

    private final NotificationApiSupport support;

    @PostMapping("/devices")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void enregistrerAppareil(@Valid @RequestBody DeviceTokenRequest request) {
        support.enregistrerAppareil(request, ApplicationCliente.CHAUFFEUR);
    }

    @DeleteMapping("/devices/{token}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoquerAppareil(@PathVariable String token) {
        support.revoquerAppareil(token);
    }

    @GetMapping("/notifications")
    public CentreNotificationsResponse notifications(@RequestParam(required = false) Integer limite) {
        return support.centre(limite);
    }

    @PatchMapping("/notifications/{id}/lue")
    public NotificationResponse marquerLue(@PathVariable Long id) {
        return support.marquerLue(id);
    }

    @PatchMapping("/notifications/lues")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void marquerToutesLues() {
        support.marquerToutesLues();
    }

    /** Vérifie la chaîne d'envoi de bout en bout, sur ses propres appareils. */
    @PostMapping("/notifications/test")
    @ResponseStatus(HttpStatus.CREATED)
    public NotificationResponse envoyerTest() {
        return support.envoyerTest();
    }
}
