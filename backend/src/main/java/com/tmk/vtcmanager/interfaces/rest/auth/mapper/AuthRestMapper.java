package com.tmk.vtcmanager.interfaces.rest.auth.mapper;

import com.tmk.vtcmanager.application.domain.auth.RegisterRequest;
import com.tmk.vtcmanager.application.domain.auth.TokenResponse;
import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.interfaces.rest.auth.dto.RegisterRequestDto;
import com.tmk.vtcmanager.interfaces.rest.auth.dto.TokenResponseDto;
import com.tmk.vtcmanager.interfaces.rest.auth.dto.UserInfoDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface AuthRestMapper {

    @Mapping(target = "phone", ignore = true)
    RegisterRequest toDomain(RegisterRequestDto request);

    TokenResponseDto toResponse(TokenResponse domain);

    UserInfoDto toUserInfoDto(UserInfo domain);
}
