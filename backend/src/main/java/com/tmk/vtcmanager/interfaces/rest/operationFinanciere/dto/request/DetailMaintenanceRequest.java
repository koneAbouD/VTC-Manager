package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record DetailMaintenanceRequest(
        @NotEmpty @Valid List<ElementMaintenanceRequest> elements
) {}
