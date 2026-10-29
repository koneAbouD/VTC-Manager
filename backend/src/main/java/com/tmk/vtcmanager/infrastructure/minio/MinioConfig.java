package com.tmk.vtcmanager.infrastructure.minio;

import io.minio.MinioClient;
import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

@Slf4j
@Configuration
public class MinioConfig {

    @Value("${app.minio.endpoint}")
    private String endpoint;

    @Value("${app.minio.access-key}")
    private String accessKey;

    @Value("${app.minio.secret-key}")
    private String secretKey;

    @Value("${app.minio.bucket}")
    private String bucket;

    /**
     * Adresse publique de MinIO (ex. https://s3.domaine), celle que les
     * téléphones atteignent. Vide en local : les URLs signées pointent alors
     * sur {@link #endpoint}.
     */
    @Value("${app.minio.public-endpoint:}")
    private String publicEndpoint;

    @Value("${app.minio.region:us-east-1}")
    private String region;

    /** Client des opérations serveur (envoi, lecture, copie, suppression), sur le réseau interne. */
    @Bean
    @Primary
    public MinioClient minioClient() {
        MinioClient client = MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
        creerBucketSiAbsent(client);
        return client;
    }

    /**
     * Client réservé à la signature des URLs remises aux applications.
     *
     * La signature S3 couvre l'hôte : une URL signée pour {@code minio:9000}
     * (nom interne Docker) n'est ni joignable depuis un téléphone ni réécrivable
     * après coup par nginx. On signe donc directement pour l'adresse publique.
     * La région est fixée pour que la signature reste purement locale (sans
     * elle, le client interroge le serveur pour la découvrir).
     */
    @Bean
    public MinioClient minioPresignClient() {
        if (publicEndpoint == null || publicEndpoint.isBlank()) {
            return minioClient();
        }
        log.info("URLs MinIO signées pour l'adresse publique {}", publicEndpoint);
        return MinioClient.builder()
                .endpoint(publicEndpoint)
                .region(region)
                .credentials(accessKey, secretKey)
                .build();
    }

    private void creerBucketSiAbsent(MinioClient client) {
        try {
            boolean exists = client.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
            if (!exists) {
                client.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
                log.info("Bucket MinIO '{}' créé", bucket);
            }
        } catch (Exception e) {
            log.error("Erreur initialisation bucket MinIO : {}", e.getMessage());
        }
    }
}