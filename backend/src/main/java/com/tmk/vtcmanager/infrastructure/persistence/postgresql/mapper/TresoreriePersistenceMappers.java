package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.TransfertTresorerie;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ClotureCaisseEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CloturePeriodeEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TransfertTresorerieEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TresoreriePersistenceMappers {

    TransfertTresorerieEntity toEntity(TransfertTresorerie domain);
    TransfertTresorerie toDomain(TransfertTresorerieEntity entity);
    List<TransfertTresorerie> toTransfertDomainList(List<TransfertTresorerieEntity> entities);

    ClotureCaisseEntity toEntity(ClotureCaisse domain);
    ClotureCaisse toDomain(ClotureCaisseEntity entity);
    List<ClotureCaisse> toClotureCaisseDomainList(List<ClotureCaisseEntity> entities);

    CloturePeriodeEntity toEntity(CloturePeriode domain);
    CloturePeriode toDomain(CloturePeriodeEntity entity);
    List<CloturePeriode> toCloturePeriodeDomainList(List<CloturePeriodeEntity> entities);
}
