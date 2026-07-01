package com.tmk.vtcmanager.interfaces.rest.common;

import com.tmk.vtcmanager.application.common.PageResult;

import java.util.List;

/**
 * Enveloppe de réponse paginée pour l'API REST. Format stable partagé par
 * toutes les listes paginées (le mobile s'appuie sur ces champs pour le
 * scroll infini).
 */
public record PageResponse<T>(
        List<T> content,
        int page,
        int size,
        long totalElements,
        int totalPages,
        boolean last
) {
    /** Construit l'enveloppe à partir d'un {@link PageResult} déjà mappé en DTO. */
    public static <T> PageResponse<T> from(PageResult<T> result) {
        return new PageResponse<>(
                result.content(),
                result.page(),
                result.size(),
                result.totalElements(),
                result.totalPages(),
                result.last());
    }
}
