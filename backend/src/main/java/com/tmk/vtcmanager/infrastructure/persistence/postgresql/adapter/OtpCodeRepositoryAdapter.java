package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.auth.OtpCode;
import com.tmk.vtcmanager.application.ports.persistence.OtpCodeRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.OtpCodeEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.OtpCodeJpaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class OtpCodeRepositoryAdapter implements OtpCodeRepository {

    private final OtpCodeJpaRepository jpaRepository;

    @Override
    @Transactional
    public OtpCode save(OtpCode otpCode) {
        return toDomain(jpaRepository.save(toEntity(otpCode)));
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<OtpCode> findDernierActif(String telephone) {
        return jpaRepository
                .findFirstByTelephoneAndConsommeFalseOrderByCreatedAtDesc(telephone)
                .map(this::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public long countEmisDepuis(String telephone, LocalDateTime depuis) {
        return jpaRepository.countByTelephoneAndCreatedAtAfter(telephone, depuis);
    }

    @Override
    @Transactional
    public void invaliderTousLesActifs(String telephone) {
        jpaRepository.invaliderTousLesActifs(telephone);
    }

    private OtpCodeEntity toEntity(OtpCode d) {
        return OtpCodeEntity.builder()
                .id(d.getId())
                .telephone(d.getTelephone())
                .codeHash(d.getCodeHash())
                .expiresAt(d.getExpiresAt())
                .tentatives(d.getTentatives())
                .consomme(d.isConsomme())
                .createdAt(d.getCreatedAt())
                .build();
    }

    private OtpCode toDomain(OtpCodeEntity e) {
        return OtpCode.builder()
                .id(e.getId())
                .telephone(e.getTelephone())
                .codeHash(e.getCodeHash())
                .expiresAt(e.getExpiresAt())
                .tentatives(e.getTentatives())
                .consomme(e.isConsomme())
                .createdAt(e.getCreatedAt())
                .build();
    }
}
