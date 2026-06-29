package com.tmk.vtcmanager.application.domain.document;

import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.Set;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Document {

    private Long id;
    private TypeDocument typeDocument;
    private String reference;
    private LocalDate dateEmission;
    private LocalDate dateExpiration;
    private DocumentStatut statut;
    private String fichierUrl;
    private String fichierNom;
    private String fichierType;

    /** Discriminant : à quelle ressource le document est rattaché */
    private CibleDocument cible;
    private Long cibleId;

    private LocalDate dateArchivage;
    private String archivedBy;
    private String raisonArchivage;

    /** Catégories de permis (vide si non-permis) */
    private Set<TypePermis> categorie;

    /** true si le document n'a pas de date d'expiration */
    private Boolean permanence;

    /** Vrai s'il s'agit d'un permis de conduire (au moins une catégorie renseignée). */
    public boolean estPermis() {
        return categorie != null && !categorie.isEmpty();
    }

    /**
     * Vrai si le document est expiré à la date donnée. Un document archivé ou
     * permanent (sans expiration) n'est jamais considéré comme expiré.
     */
    public boolean estExpireLe(LocalDate date) {
        if (statut == DocumentStatut.ARCHIVE || Boolean.TRUE.equals(permanence)) {
            return false;
        }
        if (statut == DocumentStatut.EXPIRE) {
            return true;
        }
        return dateExpiration != null && date != null && dateExpiration.isBefore(date);
    }
}