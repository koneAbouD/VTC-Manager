package com.tmk.vtcmanager.application.common;

import java.util.List;
import java.util.function.Function;

/**
 * Résultat paginé exprimé au niveau applicatif (indépendant de Spring Data).
 * Les ports de persistance renvoient ce type ; les adapters le construisent à
 * partir d'une {@code Page} Spring, et les controllers le convertissent en
 * {@code PageResponse} pour l'API.
 */
public record PageResult<T>(
        List<T> content,
        int page,
        int size,
        long totalElements
) {
    public int totalPages() {
        return size > 0 ? (int) Math.ceil((double) totalElements / (double) size) : 0;
    }

    public boolean last() {
        return page >= totalPages() - 1;
    }

    /** Transforme le contenu en conservant les métadonnées de pagination. */
    public <R> PageResult<R> map(Function<T, R> mapper) {
        return new PageResult<>(content.stream().map(mapper).toList(), page, size, totalElements);
    }
}
