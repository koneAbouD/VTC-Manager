package com.tmk.vtcmanager.interfaces.rest.admin.mapper;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.interfaces.rest.admin.dto.UpdateUserRequestDto;
import com.tmk.vtcmanager.interfaces.rest.auth.dto.UserInfoDto;
import com.tmk.vtcmanager.interfaces.rest.auth.mapper.AuthRestMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring", uses = AuthRestMapper.class)
public interface AdminRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "enabled", ignore = true)
    @Mapping(target = "roles", ignore = true)
    UserInfo toDomain(UpdateUserRequestDto request);

    UserInfoDto toUserInfoDto(UserInfo domain);
}