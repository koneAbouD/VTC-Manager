package com.tmk.vtcmanager.infrastructure.security;

import com.tmk.vtcmanager.application.ports.auth.OtpHashPort;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

@Component
public class OtpHashAdapter implements OtpHashPort {

    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    @Override
    public String hash(String rawCode) {
        return encoder.encode(rawCode);
    }

    @Override
    public boolean matches(String rawCode, String hash) {
        return encoder.matches(rawCode, hash);
    }
}
