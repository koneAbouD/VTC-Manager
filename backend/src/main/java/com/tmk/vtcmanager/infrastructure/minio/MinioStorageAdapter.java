package com.tmk.vtcmanager.infrastructure.minio;

import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import io.minio.*;
import io.minio.http.Method;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.util.concurrent.TimeUnit;

@Slf4j
@Component
public class MinioStorageAdapter implements FileStoragePort {

    private final MinioClient minioClient;
    private final String bucket;

    public MinioStorageAdapter(
            MinioClient minioClient,
            @Value("${app.minio.bucket}") String bucket) {
        this.minioClient = minioClient;
        this.bucket = bucket;
    }

    @Override
    public String upload(String objectName, InputStream content, long size, String contentType) {
        try {
            minioClient.putObject(PutObjectArgs.builder()
                    .bucket(bucket)
                    .object(objectName)
                    .stream(content, size, -1)
                    .contentType(contentType)
                    .build());
            log.info("Fichier uploadé dans MinIO : {}", objectName);
            return objectName;
        } catch (Exception e) {
            throw new RuntimeException("Erreur upload MinIO : " + e.getMessage(), e);
        }
    }

    @Override
    public InputStream download(String objectName) {
        try {
            return minioClient.getObject(GetObjectArgs.builder()
                    .bucket(bucket)
                    .object(objectName)
                    .build());
        } catch (Exception e) {
            throw new RuntimeException("Erreur download MinIO : " + e.getMessage(), e);
        }
    }

    @Override
    public void delete(String objectName) {
        try {
            minioClient.removeObject(RemoveObjectArgs.builder()
                    .bucket(bucket)
                    .object(objectName)
                    .build());
            log.info("Fichier supprimé de MinIO : {}", objectName);
        } catch (Exception e) {
            throw new RuntimeException("Erreur suppression MinIO : " + e.getMessage(), e);
        }
    }

    @Override
    public void copy(String source, String destination) {
        try {
            minioClient.copyObject(CopyObjectArgs.builder()
                    .bucket(bucket)
                    .object(destination)
                    .source(CopySource.builder()
                            .bucket(bucket)
                            .object(source)
                            .build())
                    .build());
            log.info("Fichier copié dans MinIO : {} -> {}", source, destination);
        } catch (Exception e) {
            throw new RuntimeException("Erreur copie MinIO : " + e.getMessage(), e);
        }
    }

    @Override
    public String presignedUrl(String objectName, int expirySeconds) {
        try {
            return minioClient.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .bucket(bucket)
                    .object(objectName)
                    .method(Method.GET)
                    .expiry(expirySeconds, TimeUnit.SECONDS)
                    .build());
        } catch (Exception e) {
            throw new RuntimeException("Erreur génération URL présignée : " + e.getMessage(), e);
        }
    }
}