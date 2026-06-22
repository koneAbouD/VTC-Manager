package com.tmk.vtcmanager.application.domain.document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TypeDocument {

    private Long id;
    private String nom;
    private CibleDocument cible;
    private boolean obligatoire;
}