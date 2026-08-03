package com.tmk.vtcmanager.infrastructure.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

/**
 * Fil d'exécution des envois push.
 *
 * <p>Un pool dédié, et non celui de l'application : un envoi lent ou une salve
 * de notifications ne doit pas retarder les autres traitements asynchrones. Il
 * reste volontairement petit — le volume attendu se compte en dizaines de
 * messages par jour, et FCM accepte les envois groupés.
 */
@Configuration
@EnableAsync
public class NotificationAsyncConfig {

    public static final String EXECUTOR = "notificationExecutor";

    @Bean(EXECUTOR)
    public Executor notificationExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(200);
        executor.setThreadNamePrefix("push-");
        // Au-delà de la file, l'appelant envoie lui-même plutôt que de perdre la
        // notification. Il est déjà hors transaction : le ralentir est sans
        // conséquence pour le métier.
        executor.setRejectedExecutionHandler(new java.util.concurrent.ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
