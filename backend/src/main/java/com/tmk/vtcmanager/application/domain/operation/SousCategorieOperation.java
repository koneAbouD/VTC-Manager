package com.tmk.vtcmanager.application.domain.operation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SousCategorieOperation {

    private Long id;
    private String code;
    private String libelle;
    private Long categorieId;
    private boolean actif;
}
