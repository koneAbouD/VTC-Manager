package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Calcule (sans rien écrire) le décompte d'un arrêté de compte : par bénéficiaire
 * chauffeur, le fonds de cotisation de la période face aux créances ouvertes,
 * l'allocation de compensation par antériorité, le net et le reliquat.
 *
 * <p>Fonds = Σ montant_encaisse des cotisations actives (les cotisations impayées
 * ne sont pas dans le fonds et ne sont pas comptées comme créance : mathématiquement
 * équivalent à « cotisations dues − créances incl. cotisations impayées »).</p>
 */
@RequiredArgsConstructor
public class CalculerCompteCourantUseCase {

    private static final Set<StatutLigneCotisation> STATUTS_FONDS = Set.of(
            StatutLigneCotisation.EN_ATTENTE,
            StatutLigneCotisation.PARTIELLEMENT_ENCAISSE,
            StatutLigneCotisation.ENCAISSE);

    private final LigneCotisationRepository ligneCotisationRepository;
    private final CreanceRepository creanceRepository;
    private final ChauffeurRepository chauffeurRepository;

    /** Décomptes par bénéficiaire (seuls ceux avec matière à arrêter). */
    public List<DecompteBeneficiaire> calculer(PerimetreArrete perimetre, Long perimetreId,
                                               LocalDate debut, LocalDate fin) {
        Long vehiculeId = perimetre == PerimetreArrete.VEHICULE ? perimetreId : null;
        List<DecompteBeneficiaire> resultats = new ArrayList<>();

        for (Long chauffeurId : resoudreBeneficiaires(perimetre, perimetreId, debut, fin)) {
            List<LigneCotisation> cotisations = cotisationsFonds(chauffeurId, vehiculeId, debut, fin);
            BigDecimal fond = cotisations.stream()
                    .map(LigneCotisation::getMontantEncaisse)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            List<LigneCreance> creances = creancesOuvertes(chauffeurId, vehiculeId);
            List<DecompteBeneficiaire.Allocation> allocations = allouer(fond, creances);

            BigDecimal totalCompense = allocations.stream()
                    .map(DecompteBeneficiaire.Allocation::getMontant)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal totalCreances = creances.stream()
                    .map(LigneCreance::getRestant)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal net = fond.subtract(totalCompense);
            BigDecimal reliquat = totalCreances.subtract(totalCompense);

            DecompteBeneficiaire decompte = new DecompteBeneficiaire(
                    chauffeurId, nomChauffeur(chauffeurId, cotisations, creances),
                    cotisations, fond, allocations, totalCompense, net, reliquat);
            if (decompte.estNonVide()) {
                resultats.add(decompte);
            }
        }
        return resultats;
    }

    /** Aperçu non persisté : un ArreteCompte transient prêt à afficher. */
    public ArreteCompte construireApercu(PerimetreArrete perimetre, Long perimetreId,
                                         LocalDate debut, LocalDate fin) {
        List<DecompteBeneficiaire> decomptes = calculer(perimetre, perimetreId, debut, fin);

        List<LigneArrete> lignes = new ArrayList<>();
        List<ReglementArrete> reglements = new ArrayList<>();
        for (DecompteBeneficiaire d : decomptes) {
            for (LigneCotisation cot : d.getCotisations()) {
                lignes.add(LigneArrete.builder()
                        .document(TypeDocumentCreance.COTISATION)
                        .documentId(cot.getId())
                        .chauffeurId(cot.getChauffeurId())
                        .vehiculeId(cot.getVehiculeId())
                        .montant(cot.getMontantEncaisse())
                        .sens(SensArrete.CREDIT)
                        .build());
            }
            for (DecompteBeneficiaire.Allocation alloc : d.getAllocations()) {
                LigneCreance c = alloc.getCreance();
                lignes.add(LigneArrete.builder()
                        .document(c.getDocument())
                        .documentId(c.getDocumentId())
                        .chauffeurId(d.getChauffeurId())
                        .vehiculeId(c.getVehiculeId())
                        .montant(alloc.getMontant())
                        .sens(SensArrete.DEBIT)
                        .build());
            }
            reglements.add(ReglementArrete.builder()
                    .chauffeurId(d.getChauffeurId())
                    .chauffeurNom(d.getChauffeurNom())
                    .totalCotisations(d.getFond())
                    .totalCreancesCompensees(d.getTotalCompense())
                    .montantNet(d.getNet())
                    .reliquatReporte(d.getReliquat())
                    .build());
        }

        return ArreteCompte.builder()
                .perimetre(perimetre)
                .perimetreId(perimetreId)
                .periodeDebut(debut)
                .periodeFin(fin)
                .lignes(lignes)
                .reglements(reglements)
                .build();
    }

    // ── Interne ──────────────────────────────────────────────────────────────

    private Set<Long> resoudreBeneficiaires(PerimetreArrete perimetre, Long perimetreId,
                                            LocalDate debut, LocalDate fin) {
        if (perimetre == PerimetreArrete.CHAUFFEUR) {
            return new LinkedHashSet<>(List.of(perimetreId));
        }
        // VEHICULE : tous les chauffeurs ayant un fonds sur la période OU une créance ouverte sur ce véhicule.
        Set<Long> beneficiaires = new LinkedHashSet<>();
        cotisationsFonds(null, perimetreId, debut, fin)
                .forEach(l -> beneficiaires.add(l.getChauffeurId()));
        creanceRepository.getLignesCreanceParVehicule(perimetreId).stream()
                .filter(c -> c.getDocument() != TypeDocumentCreance.COTISATION)
                .filter(c -> c.getChauffeurId() != null)
                .forEach(c -> beneficiaires.add(c.getChauffeurId()));
        return beneficiaires;
    }

    private List<LigneCotisation> cotisationsFonds(Long chauffeurId, Long vehiculeId,
                                                   LocalDate debut, LocalDate fin) {
        LigneCotisationFiltres filtres = LigneCotisationFiltres.builder()
                .chauffeurId(chauffeurId)
                .vehiculeId(vehiculeId)
                .dateDebut(debut)
                .dateFin(fin)
                .build();
        return ligneCotisationRepository.findByCriteres(filtres).stream()
                .filter(l -> STATUTS_FONDS.contains(l.getStatut()))
                .filter(l -> l.getMontantEncaisse() != null && l.getMontantEncaisse().signum() > 0)
                .toList();
    }

    private List<LigneCreance> creancesOuvertes(Long chauffeurId, Long vehiculeId) {
        return creanceRepository.getLignesCreance(chauffeurId).stream()
                .filter(c -> c.getDocument() != TypeDocumentCreance.COTISATION)
                .filter(c -> vehiculeId == null || vehiculeId.equals(c.getVehiculeId()))
                .filter(c -> c.getRestant() != null && c.getRestant().signum() > 0)
                .toList();
    }

    /** Compensation par antériorité : le fonds éteint les créances des plus anciennes aux plus récentes. */
    private List<DecompteBeneficiaire.Allocation> allouer(BigDecimal fond, List<LigneCreance> creances) {
        List<DecompteBeneficiaire.Allocation> allocations = new ArrayList<>();
        BigDecimal fondRestant = fond;
        for (LigneCreance creance : creances) {
            if (fondRestant.signum() <= 0) break;
            BigDecimal montant = fondRestant.min(creance.getRestant());
            if (montant.signum() > 0) {
                allocations.add(new DecompteBeneficiaire.Allocation(creance, montant));
                fondRestant = fondRestant.subtract(montant);
            }
        }
        return allocations;
    }

    private String nomChauffeur(Long chauffeurId, List<LigneCotisation> cotisations, List<LigneCreance> creances) {
        Optional<Chauffeur> ch = chauffeurRepository.findById(chauffeurId);
        if (ch.isPresent()) {
            String prenom = ch.get().getPrenom() != null ? ch.get().getPrenom() : "";
            String nom = ch.get().getNom() != null ? ch.get().getNom() : "";
            String complet = (prenom + " " + nom).trim();
            if (!complet.isEmpty()) return complet;
        }
        return cotisations.stream().map(LigneCotisation::getChauffeurNom).filter(n -> n != null && !n.isBlank())
                .findFirst()
                .or(() -> creances.stream().map(LigneCreance::getChauffeurNom).filter(n -> n != null && !n.isBlank()).findFirst())
                .orElse("Chauffeur #" + chauffeurId);
    }
}
