package com.tmk.vtcmanager.interfaces.rest.document.dto;

public record DocumentPresignedUrlResponse(
        String url,
        String fichierNom,
        String fichierType
) {}
