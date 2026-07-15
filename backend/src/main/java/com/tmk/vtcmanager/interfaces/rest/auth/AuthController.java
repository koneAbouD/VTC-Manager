package com.tmk.vtcmanager.interfaces.rest.auth;

import com.tmk.vtcmanager.application.usecases.auth.*;
import com.tmk.vtcmanager.interfaces.rest.auth.dto.*;
import com.tmk.vtcmanager.interfaces.rest.auth.mapper.AuthRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "Authentification", description = "Endpoints d'authentification (login, register, refresh, logout, forgot-password)")
public class AuthController {

    private final LoginUseCase loginUseCase;
    private final RegisterUseCase registerUseCase;
    private final RefreshTokenUseCase refreshTokenUseCase;
    private final LogoutUseCase logoutUseCase;
    private final ForgotPasswordUseCase forgotPasswordUseCase;
    private final RequestOtpUseCase requestOtpUseCase;
    private final VerifyOtpUseCase verifyOtpUseCase;
    private final ChauffeurPasswordLoginUseCase chauffeurPasswordLoginUseCase;
    private final AuthRestMapper mapper;

    @PostMapping("/login")
    @Operation(summary = "Connexion", description = "Authentifie un utilisateur et retourne les tokens JWT")
    public ResponseEntity<TokenResponseDto> login(@Valid @RequestBody LoginRequestDto request) {
        return ResponseEntity.ok(mapper.toResponse(loginUseCase.execute(request.username(), request.password())));
    }

    @PostMapping("/register")
    @Operation(summary = "Inscription", description = "Crée un nouveau compte utilisateur")
    public ResponseEntity<UserInfoDto> register(@Valid @RequestBody RegisterRequestDto request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(mapper.toUserInfoDto(registerUseCase.execute(mapper.toDomain(request))));
    }

    @PostMapping("/refresh")
    @Operation(summary = "Rafraîchir le token", description = "Obtient un nouveau access token à partir du refresh token")
    public ResponseEntity<TokenResponseDto> refresh(@Valid @RequestBody RefreshTokenRequestDto request) {
        return ResponseEntity.ok(mapper.toResponse(refreshTokenUseCase.execute(request.refreshToken())));
    }

    @PostMapping("/logout")
    @Operation(summary = "Déconnexion", description = "Invalide la session utilisateur")
    public ResponseEntity<Void> logout(@Valid @RequestBody RefreshTokenRequestDto request) {
        logoutUseCase.execute(request.refreshToken());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/forgot-password")
    @Operation(summary = "Mot de passe oublié", description = "Envoie un email de réinitialisation de mot de passe")
    public ResponseEntity<Void> forgotPassword(@Valid @RequestBody ForgotPasswordRequestDto request) {
        forgotPasswordUseCase.execute(request.email());
        return ResponseEntity.noContent().build();
    }

    // ── Authentification chauffeur par OTP WhatsApp ──

    @PostMapping("/otp/request")
    @Operation(summary = "Demander un code OTP",
            description = "Envoie un code de vérification par WhatsApp au chauffeur. "
                    + "Réponse neutre (204) que le numéro existe ou non.")
    public ResponseEntity<Void> requestOtp(@Valid @RequestBody OtpRequestDto request) {
        requestOtpUseCase.execute(request.telephone());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/otp/verify")
    @Operation(summary = "Vérifier un code OTP",
            description = "Vérifie le code reçu et retourne les tokens JWT en cas de succès")
    public ResponseEntity<TokenResponseDto> verifyOtp(@Valid @RequestBody OtpVerifyDto request) {
        return ResponseEntity.ok(mapper.toResponse(
                verifyOtpUseCase.execute(request.telephone(), request.code())));
    }

    @PostMapping("/chauffeur/login")
    @Operation(summary = "Connexion chauffeur par mot de passe",
            description = "Authentifie un chauffeur via identifiant (téléphone) + mot de passe")
    public ResponseEntity<TokenResponseDto> chauffeurLogin(@Valid @RequestBody ChauffeurLoginDto request) {
        return ResponseEntity.ok(mapper.toResponse(
                chauffeurPasswordLoginUseCase.execute(request.identifiant(), request.motDePasse())));
    }
}