package com.tmk.vtcmanager.application.domain.operation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OperationFinanciere {

    private Long id;
    private String reference;
    private TypeOperation typeOperation;
    private CategorieOperation categorie;
    private SousCategorieOperation sousCategorie;
    private Chauffeur chauffeur;
    private Vehicule vehicule;
    private BigDecimal montant;
    private ModePaiement modePaiement;
    private LocalDate dateOperation;
    private String commentaire;
    private StatutOperation statut;
    private DetailMaintenance detailMaintenance;
}
