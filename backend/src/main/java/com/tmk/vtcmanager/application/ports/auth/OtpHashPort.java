package com.tmk.vtcmanager.application.ports.auth;

/** Hachage à sens unique des codes OTP (le code en clair n'est jamais persisté). */
public interface OtpHashPort {

    String hash(String rawCode);

    boolean matches(String rawCode, String hash);
}
