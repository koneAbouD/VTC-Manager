package com.tmk.vtcmanager.interfaces.rest.contravention.dto.request;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record PaymentRequest(
        @NotNull BigDecimal montantPaye
) {}