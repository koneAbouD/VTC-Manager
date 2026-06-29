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
import com.tmk.vtcmanager.application.exception.ChauffeurNeTravaillePasCeJourException;
import com.tmk.vtcmanager.application.exception.ModePaiementNonAutoriseException;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.RoleInsufficientException;
import com.tmk.vtcmanager.application.exception.SessionExpiredException;
import com.tmk.vtcmanager.application.exception.VehiculeOuChauffeurSansLigneCotisationActiveException;
import com.tmk.vtcmanager.application.exception.VehiculeOuChauffeurSansLigneActiveException;
import jakarta.servlet.http.HttpServletRequest;
import org.hibernate.exception.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /** Taille max d'un fichier (telle que configurée dans application.yml), ex. "10MB". */
    @Value("${spring.servlet.multipart.max-file-size:10MB}")
    private String maxFileSize;

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

    // ── Fabrique de réponse + journalisation centralisée ───────────────────
    //
    // Tout passe par cette méthode : un seul point pour des logs cohérents.
    //   • 5xx (erreurs serveur inattendues) → ERROR + stacktrace pour diagnostic.
    //   • 4xx (erreurs métier/client attendues) → WARN concis, sans stacktrace.

    private ResponseEntity<ApiError> respond(HttpStatus status, String code, String message,
                                             HttpServletRequest request, List<String> details, Exception ex) {
        logError(status, code, message, request, ex);
        return ResponseEntity.status(status).body(
                ApiError.builder()
                        .status(status.value())
                        .error(code)
                        .message(message)
                        .path(request.getRequestURI())
                        .timestamp(LocalDateTime.now())
                        .details(details)
                        .build()
        );
    }

    private ResponseEntity<ApiError> respond(HttpStatus status, String code, String message,
                                             HttpServletRequest request, Exception ex) {
        return respond(status, code, message, request, null, ex);
    }

    private void logError(HttpStatus status, String code, String message,
                          HttpServletRequest request, Exception ex) {
        String req = request.getMethod() + " " + request.getRequestURI();
        if (status.is5xxServerError()) {
            log.error("[{}] {} ({}) -> {} {} : {}", req, ex.getClass().getSimpleName(), code,
                    status.value(), status.getReasonPhrase(), message, ex);
        } else {
            log.warn("[{}] {} ({}) -> {} : {}", req, ex.getClass().getSimpleName(), code,
                    status.value(), message);
        }
    }

    // ── Intégrité base de données ──────────────────────────────────────────

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiError> handleDataIntegrity(DataIntegrityViolationException ex, HttpServletRequest request) {
        // Déterminer le SQLState pour distinguer NOT NULL (23502) de UNIQUE (23505) et CHECK (23514)
        String sqlState = "";
        if (ex.getCause() instanceof ConstraintViolationException cve && cve.getSQLException() != null) {
            sqlState = cve.getSQLException().getSQLState();
        }

        if ("23502".equals(sqlState)) {
            // Violation NOT NULL : erreur de données côté client → 400
            return respond(HttpStatus.BAD_REQUEST, HttpStatus.BAD_REQUEST.getReasonPhrase(),
                    "Données incomplètes : un champ obligatoire est manquant.", request, ex);
        }

        // Violation UNIQUE (23505) ou CHECK (23514) → 409
        String message = "Opération refusée : une valeur unique est déjà utilisée.";
        String raw = ex.getMessage() != null ? ex.getMessage() : "";
        Matcher m = CONSTRAINT_PATTERN.matcher(raw);
        if (m.find()) {
            String constraintName = m.group(1);
            message = CONSTRAINT_MESSAGES.getOrDefault(constraintName, message);
        }
        return respond(HttpStatus.CONFLICT, HttpStatus.CONFLICT.getReasonPhrase(), message, request, ex);
    }

    // ── Dépassement de taille d'un document uploadé ────────────────────────

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiError> handleMaxUploadSize(MaxUploadSizeExceededException ex, HttpServletRequest request) {
        String message = "Le document est trop volumineux. La taille maximale autorisée est de "
                + maxFileSize + ". Veuillez choisir un fichier plus léger.";
        return respond(HttpStatus.PAYLOAD_TOO_LARGE, "DOCUMENT_TROP_VOLUMINEUX", message, request,
                List.of("tailleMaxAutorisee:" + maxFileSize), ex);
    }

    // ── Conflits / ressources ──────────────────────────────────────────────

    @ExceptionHandler(ChauffeurAlreadyAssignedException.class)
    public ResponseEntity<ApiError> handleChauffeurAlreadyAssigned(ChauffeurAlreadyAssignedException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "CHAUFFEUR_ALREADY_ASSIGNED", ex.getMessage(), request,
                List.of(
                        "chauffeurId:" + ex.getChauffeurId(),
                        "chauffeurNom:" + ex.getChauffeurNom(),
                        "vehiculeActuelId:" + ex.getVehiculeActuelId(),
                        "vehiculeActuelImmatriculation:" + ex.getVehiculeActuelImmatriculation()
                ), ex);
    }

    @ExceptionHandler(ResourceAlreadyExistsException.class)
    public ResponseEntity<ApiError> handleAlreadyExists(ResourceAlreadyExistsException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, HttpStatus.CONFLICT.getReasonPhrase(), ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LigneCotisationNotFoundException.class)
    public ResponseEntity<ApiError> handleLigneCotisationNotFound(LigneCotisationNotFoundException ex, HttpServletRequest request) {
        return respond(HttpStatus.NOT_FOUND, HttpStatus.NOT_FOUND.getReasonPhrase(), ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LigneCotisationDejaSoldeeException.class)
    public ResponseEntity<ApiError> handleLigneCotisationDejaSoldee(LigneCotisationDejaSoldeeException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "LIGNE_COTISATION_DEJA_SOLDEE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(VehiculeOuChauffeurSansLigneCotisationActiveException.class)
    public ResponseEntity<ApiError> handleSansLigneCotisationActive(VehiculeOuChauffeurSansLigneCotisationActiveException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "AUCUNE_LIGNE_COTISATION_ACTIVE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(EncaissementDepasseMontantDuException.class)
    public ResponseEntity<ApiError> handleDepasseMontantDu(EncaissementDepasseMontantDuException ex, HttpServletRequest request) {
        return respond(HttpStatus.UNPROCESSABLE_ENTITY, "ENCAISSEMENT_DEPASSE_MONTANT_DU", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LigneRecetteNotFoundException.class)
    public ResponseEntity<ApiError> handleLigneRecetteNotFound(LigneRecetteNotFoundException ex, HttpServletRequest request) {
        return respond(HttpStatus.NOT_FOUND, HttpStatus.NOT_FOUND.getReasonPhrase(), ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LigneRecetteDejaSoldeeException.class)
    public ResponseEntity<ApiError> handleLigneRecetteDejaSoldee(LigneRecetteDejaSoldeeException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "LIGNE_RECETTE_DEJA_SOLDEE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(VehiculeOuChauffeurSansLigneActiveException.class)
    public ResponseEntity<ApiError> handleSansLigneActive(VehiculeOuChauffeurSansLigneActiveException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "AUCUNE_LIGNE_RECETTE_ACTIVE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(EncaissementDepasseMontantAttenduException.class)
    public ResponseEntity<ApiError> handleDepasseMontant(EncaissementDepasseMontantAttenduException ex, HttpServletRequest request) {
        return respond(HttpStatus.UNPROCESSABLE_ENTITY, "ENCAISSEMENT_DEPASSE_MONTANT", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(ModePaiementNonAutoriseException.class)
    public ResponseEntity<ApiError> handleModePaiementNonAutorise(ModePaiementNonAutoriseException ex, HttpServletRequest request) {
        return respond(HttpStatus.UNPROCESSABLE_ENTITY, "MODE_PAIEMENT_NON_AUTORISE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(ChauffeurNeTravaillePasCeJourException.class)
    public ResponseEntity<ApiError> handleChauffeurNeTravaillePasCeJour(
            ChauffeurNeTravaillePasCeJourException ex, HttpServletRequest request) {
        return respond(HttpStatus.UNPROCESSABLE_ENTITY, "CHAUFFEUR_NE_TRAVAILLE_PAS_CE_JOUR",
                ex.getMessage(), request, ex);
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(ResourceNotFoundException ex, HttpServletRequest request) {
        return respond(HttpStatus.NOT_FOUND, HttpStatus.NOT_FOUND.getReasonPhrase(), ex.getMessage(), request, ex);
    }

    @ExceptionHandler(RoleInsufficientException.class)
    public ResponseEntity<ApiError> handleRoleInsufficient(RoleInsufficientException ex, HttpServletRequest request) {
        return respond(HttpStatus.FORBIDDEN, HttpStatus.FORBIDDEN.getReasonPhrase(), ex.getMessage(), request, ex);
    }

    @ExceptionHandler(SessionExpiredException.class)
    public ResponseEntity<ApiError> handleSessionExpired(SessionExpiredException ex, HttpServletRequest request) {
        return respond(HttpStatus.UNAUTHORIZED, "SESSION_EXPIRED", ex.getMessage(), request, ex);
    }

    // ── Validation des requêtes ────────────────────────────────────────────

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        List<String> details = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
                .toList();
        return respond(HttpStatus.BAD_REQUEST, HttpStatus.BAD_REQUEST.getReasonPhrase(),
                "Validation échouée", request, details, ex);
    }

    // ── Pénalités ──────────────────────────────────────────────────────────

    @ExceptionHandler(LignePenaliteNotFoundException.class)
    public ResponseEntity<ApiError> handleLignePenaliteNotFound(LignePenaliteNotFoundException ex, HttpServletRequest request) {
        return respond(HttpStatus.NOT_FOUND, HttpStatus.NOT_FOUND.getReasonPhrase(), ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LignePenaliteNonEncaissableException.class)
    public ResponseEntity<ApiError> handleNonEncaissable(LignePenaliteNonEncaissableException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "PENALITE_NON_ENCAISSABLE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LignePenaliteNonExecutableException.class)
    public ResponseEntity<ApiError> handleNonExecutable(LignePenaliteNonExecutableException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "PENALITE_NON_EXECUTABLE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LignePenaliteNonNotifiableException.class)
    public ResponseEntity<ApiError> handleNonNotifiable(LignePenaliteNonNotifiableException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "PENALITE_NON_NOTIFIABLE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LignePenaliteNonDemarrableException.class)
    public ResponseEntity<ApiError> handleNonDemarrable(LignePenaliteNonDemarrableException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "PENALITE_NON_DEMARRABLE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LignePenaliteNonLevableException.class)
    public ResponseEntity<ApiError> handleNonLevable(LignePenaliteNonLevableException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "PENALITE_NON_LEVABLE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(LignePenaliteDejaTermineeException.class)
    public ResponseEntity<ApiError> handlePenaliteDejaTerminee(LignePenaliteDejaTermineeException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "PENALITE_DEJA_TERMINEE", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(EncaissementPenaliteDepasseMontantException.class)
    public ResponseEntity<ApiError> handleEncaissementDepassePenalite(EncaissementPenaliteDepasseMontantException ex, HttpServletRequest request) {
        return respond(HttpStatus.UNPROCESSABLE_ENTITY, "ENCAISSEMENT_PENALITE_DEPASSE_MONTANT", ex.getMessage(), request, ex);
    }

    @ExceptionHandler(AucunePenaliteAmendePendingException.class)
    public ResponseEntity<ApiError> handleAucunePenaliteAmende(AucunePenaliteAmendePendingException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, "AUCUNE_PENALITE_AMENDE_PENDING", ex.getMessage(), request, ex);
    }

    // ── Erreurs génériques d'argument / d'état ─────────────────────────────

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiError> handleIllegalArgument(IllegalArgumentException ex, HttpServletRequest request) {
        return respond(HttpStatus.BAD_REQUEST, HttpStatus.BAD_REQUEST.getReasonPhrase(), ex.getMessage(), request, ex);
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ApiError> handleIllegalState(IllegalStateException ex, HttpServletRequest request) {
        return respond(HttpStatus.CONFLICT, HttpStatus.CONFLICT.getReasonPhrase(), ex.getMessage(), request, ex);
    }

    // ── Filet de sécurité : toute exception non gérée ──────────────────────
    // Le détail technique est journalisé (ERROR + stacktrace) mais jamais
    // exposé au client, qui reçoit un message neutre.

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGeneric(Exception ex, HttpServletRequest request) {
        return respond(HttpStatus.INTERNAL_SERVER_ERROR, HttpStatus.INTERNAL_SERVER_ERROR.getReasonPhrase(),
                "Une erreur interne est survenue. Veuillez réessayer plus tard.", request, ex);
    }
}
