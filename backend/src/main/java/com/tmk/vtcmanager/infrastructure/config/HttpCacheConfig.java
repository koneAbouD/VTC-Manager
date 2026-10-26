package com.tmk.vtcmanager.infrastructure.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Revalidation des lectures par ETag (voir {@link EtagLecturesFilter}).
 *
 * <p>Ordre par défaut (le plus bas) : le filtre s'exécute après Spring
 * Security, une requête refusée n'est donc jamais revalidée.
 */
@Configuration
public class HttpCacheConfig {

    @Bean
    public FilterRegistrationBean<EtagLecturesFilter> etagLecturesFilter() {
        FilterRegistrationBean<EtagLecturesFilter> registration =
                new FilterRegistrationBean<>(new EtagLecturesFilter());
        registration.addUrlPatterns("/api/*");
        registration.setName("etagLecturesFilter");
        return registration;
    }
}
