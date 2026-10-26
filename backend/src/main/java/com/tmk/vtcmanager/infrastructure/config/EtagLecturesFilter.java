package com.tmk.vtcmanager.infrastructure.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpMethod;
import org.springframework.web.filter.ShallowEtagHeaderFilter;

import java.io.InputStream;

/**
 * ETag sur les lectures de l'API : une application qui renvoie l'ETag de sa
 * dernière réponse ({@code If-None-Match}) reçoit un 304 sans corps quand rien
 * n'a changé. Le serveur calcule toujours la réponse ; c'est le réseau mobile
 * qu'on épargne, pas la base.
 *
 * <p>Le filtre de Spring écarte les réponses marquées {@code no-store}, ce que
 * Spring Security pose sur toutes. On garde cet en-tête — aucun cache
 * intermédiaire ni navigateur ne doit conserver ces données — et on calcule
 * l'ETag quand même : la revalidation est explicite, demandée par le client
 * qui détient déjà la réponse.
 *
 * <p>ETag faible : Tomcat ne compresse pas une réponse porteuse d'un ETag fort.
 */
public class EtagLecturesFilter extends ShallowEtagHeaderFilter {

    public EtagLecturesFilter() {
        setWriteWeakETag(true);
    }

    @Override
    protected boolean isEligibleForEtag(HttpServletRequest request, HttpServletResponse response,
                                        int responseStatusCode, InputStream inputStream) {
        return !response.isCommitted()
                && responseStatusCode >= 200 && responseStatusCode < 300
                && HttpMethod.GET.matches(request.getMethod());
    }
}
