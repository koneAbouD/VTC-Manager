package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.OtpCodeEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface OtpCodeJpaRepository extends JpaRepository<OtpCodeEntity, Long> {

    Optional<OtpCodeEntity> findFirstByTelephoneAndConsommeFalseOrderByCreatedAtDesc(String telephone);

    long countByTelephoneAndCreatedAtAfter(String telephone, LocalDateTime depuis);

    @Modifying
    @Query("UPDATE OtpCodeEntity o SET o.consomme = true WHERE o.telephone = :telephone AND o.consomme = false")
    void invaliderTousLesActifs(@Param("telephone") String telephone);
}
