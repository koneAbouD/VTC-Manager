# syntax=docker/dockerfile:1

###############################################
# Stage 1 — Build du jar avec Maven + JDK 21  #
###############################################
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# 1) Résolution des dépendances en couche cachée (rebuild rapide si seul le code change)
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline

# 2) Compilation et packaging (tests ignorés ici : à exécuter dans la CI)
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q clean package -DskipTests

# 3) Extraction des couches Spring Boot pour optimiser le cache d'image runtime
RUN mkdir -p target/extracted \
    && java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

###############################################
# Stage 2 — Image runtime légère (JRE 21)     #
###############################################
FROM eclipse-temurin:21-jre-alpine AS runtime

# curl pour le HEALTHCHECK ; utilisateur non-root pour la sécurité
RUN apk add --no-cache curl \
    && addgroup -S app && adduser -S app -G app

WORKDIR /app

# Copie des couches extraites (les moins volatiles d'abord)
COPY --from=build /build/target/extracted/dependencies/ ./
COPY --from=build /build/target/extracted/spring-boot-loader/ ./
COPY --from=build /build/target/extracted/snapshot-dependencies/ ./
COPY --from=build /build/target/extracted/application/ ./

USER app

EXPOSE 8081

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC" \
    SPRING_PROFILES_ACTIVE=prod

# Healthcheck via l'endpoint Actuator
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:8081/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
