package com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities;

import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.chauffeur.Genre;
import com.tmk.vtcmanager.application.domain.chauffeur.TypeChauffeur;
import jakarta.persistence.*;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.*;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.LocalDate;

@Entity
@Table(name = ChauffeurEntity.TABLE_NAME)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChauffeurEntity extends AbstractAuditEntity {

    public static final String TABLE_NAME = "chauffeurs";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * Jeton de version de la fiche, tenu par la base : un trigger l'incrémente
     * à chaque UPDATE de la ligne, quel qu'en soit l'auteur. Relu après chaque
     * écriture ; jamais écrit par l'application. (Pas de {@code @Version} JPA :
     * il changerait la façon dont Hibernate reconnaît une entité nouvelle, et
     * les références détachées construites par les mappers passeraient pour
     * des insertions.)
     */
    @Generated(event = {EventType.INSERT, EventType.UPDATE})
    @Column(name = "version", insertable = false, updatable = false)
    private Long version;

    @NotBlank
    @Column(nullable = false)
    private String nom;

    @NotBlank
    @Column(nullable = false)
    private String prenom;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Genre genre;

    @Enumerated(EnumType.STRING)
    @Column(length = 15)
    private TypeChauffeur type;

    @Column(name = "date_naissance")
    private LocalDate dateNaissance;

    @Column(name = "photo_url")
    private String photoUrl;

    private String telephone;

    @Email
    private String email;

    private String adresse;

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private ChauffeurStatus statut;

    @Enumerated(EnumType.STRING)
    @Column(name = "statut_manuel", length = 30)
    private ChauffeurStatus statutManuel;

    @Column(name = "keycloak_user_id", length = 36)
    private String keycloakUserId;

    @Column(name = "date_suspension")
    private LocalDate dateSuspension;

    @Column(name = "date_embauche")
    private LocalDate dateEmbauche;

    @OneToOne(mappedBy = "chauffeur", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private GeolocalisationEntity geolocalisation;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicule_id")
    private VehiculeEntity vehicule;
}
