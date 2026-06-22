package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import java.util.List;

public record DetailMaintenanceResponse(
        Long id,
        List<ElementMaintenanceResponse> elements
) {}
