package com.tmk.vtcmanager.interfaces.rest.admin.dto;

import jakarta.validation.constraints.NotNull;

public record SetEnabledRequestDto(
        @NotNull(message = "Le champ 'enabled' est requis") Boolean enabled
) {}