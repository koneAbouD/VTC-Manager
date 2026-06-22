package com.tmk.vtcmanager.interfaces.rest.exception;

import com.tmk.vtcmanager.application.exception.AucunePenaliteAmendePendingException;
import com.tmk.vtcmanager.application.exception.ChauffeurAlreadyAssignedException;
import com.tmk.vtcmanager.application.exception.EncaissementPenaliteDepasseMontantException;
import com.tmk.vtcmanager.application.exception.LignePenaliteDejaTermineeException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonDemarrableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonEncaissableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonExecutableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonLevableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNonNotifiableException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.exception.EncaissementDepasseMontantAttenduException;
import com.tmk.vtcmanager.application.exception.EncaissementDepasseMontantDuException;
import com.tmk.vtcmanager.application.exception.LigneCotisationDejaSoldeeException;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.exception.LigneRecetteDejaSoldeeException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.exception.ModePaiementNonAutoriseException;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.RoleInsufficientException;
import com.tmk.vtcmanager.application.exception.VehiculeOuChauffeurSansLigneCotisationActiveException;
import com.tmk.vtcmanager.application.exception.VehiculeOuChauffeurSansLigneActiveException;
import jakarta.servlet.http.HttpServletRequest;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@RestControllerAdvice
public class GlobalExceptionHandler {

    // ── Messages lisibles par contrainte DB ────────────────────────────────
    private static final Map<String, String> CONSTRAINT_MESSAGES = Map.of(
        "vehicules_immatriculation_key",              "Cette immatriculation est déjà utilisée par un autre véhicule.",
        "chauffeurs_email_key",                       "Un chauffeur avec cet e-mail existe déjà.",
        "chauffeurs_telephone_key",                   "Un chauffeur avec ce numéro de téléphone existe déjà.",
        "utilisateurs_username_key",                  "Ce nom d'utilisateur est déjà pris.",
        "utilisateurs_email_key",                     "Un utilisateur avec cet e-mail existe déjà.",
        "chk_condition_travail_mode_encaissement",    "Mode d'encaissement invalide. Valeurs acceptées : Espèces, Mobile Money, Les deux.",
        "chk_condition_travail_type_recette",         "Type de recette invalide.",
        "chk_condition_travail_frequence_versement",  "Fréquence de versement invalide."
    );

    // Supporte les formats PostgreSQL : constraint "name" et H2 : constraint [name]
    private static final Pattern CONSTRAINT_PATTERN =
            Pattern.compile("constraint [\"\\[]([\\w]+)[\"\\]]", Pattern.CASE_INSENSITIVE);

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiError> handleDataIntegrity(DataIntegrityViolationException ex, HttpServletRequest request) {
        // Déterminer le SQLState pour distinguer NOT NULL (23502) de UNIQUE (23505) et CHECK (23514)
        String sqlState = "";
        if (ex.getCause() instanceof ConstraintViolationException cve && cve.getSQLException() != null) {
            sqlState = cve.getSQLException().getSQLState();
        }

        if ("23502".equals(sqlState)) {
            // Violation NOT NULL : erreur de données côté client → 400
            return ResponseEntity.badRequest().body(
                    ApiError.builder()
                            .status(HttpStatus.BAD_REQUEST.value())
                            .error(HttpStatus.BAD_REQUEST.getReasonPhrase())
                            .message("Données incomplètes : un champ obligatoire est manquant.")
                            .path(request.getRequestURI())
                            .timestamp(LocalDateTime.now())
                            .build()
            );
        }

        // Violation UNIQUE (23505) ou CHECK (23514) → 409
        String message = "Opération refusée : une valeur unique est déjà utilisée.";
        String raw = ex.getMessage() != null ? ex.getMessage() : "";
        Matcher m = CONSTRAINT_PATTERN.matcher(raw);
        if (m.find()) {
            String constraintName = m.group(1);
            message = CONSTRAINT_MESSAGES.getOrDefault(constraintName, message);
        }
        return ResponseEntity.status(HttpStatus.CONFLICT).body(
                ApiError.builder()
                        .status(HttpStatus.CONFLICT.value())
                        .error(HttpStatus.CONFLICT.getReasonPhrase())
                        .message(message)
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(ChauffeurAlreadyAssignedException.class)
    public ResponseEntity<ApiError> handleChauffeurAlreadyAssigned(ChauffeurAlreadyAssignedException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(
                ApiError.builder()
                        .status(HttpStatus.CONFLICT.value())
                        .error("CHAUFFEUR_ALREADY_ASSIGNED")
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .details(List.of(
                                "chauffeurId:" + ex.getChauffeurId(),
                                "chauffeurNom:" + ex.getChauffeurNom(),
                                "vehiculeActuelId:" + ex.getVehiculeActuelId(),
                                "vehiculeActuelImmatriculation:" + ex.getVehiculeActuelImmatriculation()
                        ))
                        .build()
        );
    }

    @ExceptionHandler(ResourceAlreadyExistsException.class)
    public ResponseEntity<ApiError> handleAlreadyExists(ResourceAlreadyExistsException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(
                ApiError.builder()
                        .status(HttpStatus.CONFLICT.value())
                        .error(HttpStatus.CONFLICT.getReasonPhrase())
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(LigneCotisationNotFoundException.class)
    public ResponseEntity<ApiError> handleLigneCotisationNotFound(LigneCotisationNotFoundException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiError.builder()
                .status(HttpStatus.NOT_FOUND.value()).error(HttpStatus.NOT_FOUND.getReasonPhrase())
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(java.time.LocalDateTime.now()).build());
    }

    @ExceptionHandler(LigneCotisationDejaSoldeeException.class)
    public ResponseEntity<ApiError> handleLigneCotisationDejaSoldee(LigneCotisationDejaSoldeeException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("LIGNE_COTISATION_DEJA_SOLDEE")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(java.time.LocalDateTime.now()).build());
    }

    @ExceptionHandler(VehiculeOuChauffeurSansLigneCotisationActiveException.class)
    public ResponseEntity<ApiError> handleSansLigneCotisationActive(VehiculeOuChauffeurSansLigneCotisationActiveException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("AUCUNE_LIGNE_COTISATION_ACTIVE")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(java.time.LocalDateTime.now()).build());
    }

    @ExceptionHandler(EncaissementDepasseMontantDuException.class)
    public ResponseEntity<ApiError> handleDepasseMontantDu(EncaissementDepasseMontantDuException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(ApiError.builder()
                .status(HttpStatus.UNPROCESSABLE_ENTITY.value()).error("ENCAISSEMENT_DEPASSE_MONTANT_DU")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(java.time.LocalDateTime.now()).build());
    }

    @ExceptionHandler(LigneRecetteNotFoundException.class)
    public ResponseEntity<ApiError> handleLigneRecetteNotFound(LigneRecetteNotFoundException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(
                ApiError.builder()
                        .status(HttpStatus.NOT_FOUND.value())
                        .error(HttpStatus.NOT_FOUND.getReasonPhrase())
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(LigneRecetteDejaSoldeeException.class)
    public ResponseEntity<ApiError> handleLigneRecetteDejaSoldee(LigneRecetteDejaSoldeeException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(
                ApiError.builder()
                        .status(HttpStatus.CONFLICT.value())
                        .error("LIGNE_RECETTE_DEJA_SOLDEE")
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(VehiculeOuChauffeurSansLigneActiveException.class)
    public ResponseEntity<ApiError> handleSansLigneActive(VehiculeOuChauffeurSansLigneActiveException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(
                ApiError.builder()
                        .status(HttpStatus.CONFLICT.value())
                        .error("AUCUNE_LIGNE_RECETTE_ACTIVE")
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(EncaissementDepasseMontantAttenduException.class)
    public ResponseEntity<ApiError> handleDepasseMontant(EncaissementDepasseMontantAttenduException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(
                ApiError.builder()
                        .status(HttpStatus.UNPROCESSABLE_ENTITY.value())
                        .error("ENCAISSEMENT_DEPASSE_MONTANT")
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(ModePaiementNonAutoriseException.class)
    public ResponseEntity<ApiError> handleModePaiementNonAutorise(ModePaiementNonAutoriseException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(
                ApiError.builder()
                        .status(HttpStatus.UNPROCESSABLE_ENTITY.value())
                        .error("MODE_PAIEMENT_NON_AUTORISE")
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(ResourceNotFoundException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(
                ApiError.builder()
                        .status(HttpStatus.NOT_FOUND.value())
                        .error(HttpStatus.NOT_FOUND.getReasonPhrase())
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(RoleInsufficientException.class)
    public ResponseEntity<ApiError> handleRoleInsufficient(RoleInsufficientException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(
                ApiError.builder()
                        .status(HttpStatus.FORBIDDEN.value())
                        .error(HttpStatus.FORBIDDEN.getReasonPhrase())
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        List<String> details = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
                .toList();
        return ResponseEntity.badRequest().body(
                ApiError.builder()
                        .status(HttpStatus.BAD_REQUEST.value())
                        .error(HttpStatus.BAD_REQUEST.getReasonPhrase())
                        .message("Validation échouée")
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .details(details)
                        .build()
        );
    }

    @ExceptionHandler(LignePenaliteNotFoundException.class)
    public ResponseEntity<ApiError> handleLignePenaliteNotFound(LignePenaliteNotFoundException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiError.builder()
                .status(HttpStatus.NOT_FOUND.value()).error(HttpStatus.NOT_FOUND.getReasonPhrase())
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(LignePenaliteNonEncaissableException.class)
    public ResponseEntity<ApiError> handleNonEncaissable(LignePenaliteNonEncaissableException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("PENALITE_NON_ENCAISSABLE")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(LignePenaliteNonExecutableException.class)
    public ResponseEntity<ApiError> handleNonExecutable(LignePenaliteNonExecutableException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("PENALITE_NON_EXECUTABLE")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(LignePenaliteNonNotifiableException.class)
    public ResponseEntity<ApiError> handleNonNotifiable(LignePenaliteNonNotifiableException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("PENALITE_NON_NOTIFIABLE")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(LignePenaliteNonDemarrableException.class)
    public ResponseEntity<ApiError> handleNonDemarrable(LignePenaliteNonDemarrableException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("PENALITE_NON_DEMARRABLE")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(LignePenaliteNonLevableException.class)
    public ResponseEntity<ApiError> handleNonLevable(LignePenaliteNonLevableException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("PENALITE_NON_LEVABLE")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(LignePenaliteDejaTermineeException.class)
    public ResponseEntity<ApiError> handlePenaliteDejaTerminee(LignePenaliteDejaTermineeException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("PENALITE_DEJA_TERMINEE")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(EncaissementPenaliteDepasseMontantException.class)
    public ResponseEntity<ApiError> handleEncaissementDepassePenalite(EncaissementPenaliteDepasseMontantException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(ApiError.builder()
                .status(HttpStatus.UNPROCESSABLE_ENTITY.value()).error("ENCAISSEMENT_PENALITE_DEPASSE_MONTANT")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(AucunePenaliteAmendePendingException.class)
    public ResponseEntity<ApiError> handleAucunePenaliteAmende(AucunePenaliteAmendePendingException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.builder()
                .status(HttpStatus.CONFLICT.value()).error("AUCUNE_PENALITE_AMENDE_PENDING")
                .message(ex.getMessage()).path(request.getRequestURI()).timestamp(LocalDateTime.now()).build());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiError> handleIllegalArgument(IllegalArgumentException ex, HttpServletRequest request) {
        return ResponseEntity.badRequest().body(
                ApiError.builder()
                        .status(HttpStatus.BAD_REQUEST.value())
                        .error(HttpStatus.BAD_REQUEST.getReasonPhrase())
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ApiError> handleIllegalState(IllegalStateException ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(
                ApiError.builder()
                        .status(HttpStatus.CONFLICT.value())
                        .error(HttpStatus.CONFLICT.getReasonPhrase())
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGeneric(Exception ex, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(
                ApiError.builder()
                        .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
                        .error(HttpStatus.INTERNAL_SERVER_ERROR.getReasonPhrase())
                        .message(ex.getMessage())
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .build()
        );
    }
}
