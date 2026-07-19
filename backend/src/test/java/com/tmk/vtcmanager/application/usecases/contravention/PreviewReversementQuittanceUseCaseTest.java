package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.contravention.reversement.ApercuReversementQuittance;
import com.tmk.vtcmanager.application.domain.contravention.reversement.StatutLigneReversement;
import com.tmk.vtcmanager.application.ports.extraction.LigneQuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversement;
import com.tmk.vtcmanager.application.ports.extraction.QuittanceReversementExtractorPort;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PreviewReversementQuittanceUseCaseTest {

    private QuittanceReversementExtractorPort extractor;
    private ContraventionRepository contraventionRepository;
    private FileStoragePort fileStoragePort;
    private PreviewReversementQuittanceUseCase useCase;

    @BeforeEach
    void setUp() {
        extractor = mock(QuittanceReversementExtractorPort.class);
        contraventionRepository = mock(ContraventionRepository.class);
        fileStoragePort = mock(FileStoragePort.class);
        useCase = new PreviewReversementQuittanceUseCase(
                extractor, contraventionRepository, fileStoragePort);
    }

    private static Contravention contravention(Long id, String montant, ContraventionStatus statut) {
        return Contravention.builder().id(id).montant(new BigDecimal(montant)).statut(statut).build();
    }

    @Test
    void classe_chaque_ligne_et_calcule_le_total_reversable() {
        when(extractor.extraire(any())).thenReturn(new QuittanceReversement(
                "LIQ-1", "SOL-1", "ABOU-DRAMANE KONE", LocalDate.of(2026, 7, 3),
                List.of(
                        new LigneQuittanceReversement("C000000000000000A", "AA-1", "045", new BigDecimal("5000")),
                        new LigneQuittanceReversement("C000000000000000B", "AA-1", "046", new BigDecimal("10000")),
                        new LigneQuittanceReversement("C000000000000000C", "AA-1", "046", new BigDecimal("10000")),
                        new LigneQuittanceReversement("C000000000000000D", "AA-1", "045", new BigDecimal("10000")))));

        when(contraventionRepository.findByNumero("C000000000000000A"))
                .thenReturn(Optional.of(contravention(10L, "5000", ContraventionStatus.EN_ATTENTE)));
        when(contraventionRepository.findByNumero("C000000000000000B"))
                .thenReturn(Optional.of(contravention(11L, "10000", ContraventionStatus.REVERSE)));
        when(contraventionRepository.findByNumero("C000000000000000C"))
                .thenReturn(Optional.empty());
        when(contraventionRepository.findByNumero("C000000000000000D"))
                .thenReturn(Optional.of(contravention(12L, "8000", ContraventionStatus.EN_ATTENTE)));

        ApercuReversementQuittance apercu = useCase.previsualiser(
                new ByteArrayInputStream("pdf".getBytes()), "quittance.pdf", "application/pdf");

        assertThat(apercu.getNumeroLiquidation()).isEqualTo("LIQ-1");
        assertThat(apercu.getDemandeur()).isEqualTo("ABOU-DRAMANE KONE");
        assertThat(apercu.getDocumentSourcePath()).startsWith("reversements/");
        assertThat(apercu.getLignes()).extracting("statut").containsExactly(
                StatutLigneReversement.A_REVERSER,
                StatutLigneReversement.DEJA_REVERSEE,
                StatutLigneReversement.INTROUVABLE,
                StatutLigneReversement.A_REVERSER);

        // Ligne D : montant quittance (10000) ≠ montant système (8000).
        assertThat(apercu.getLignes().get(3).isMontantDivergent()).isTrue();
        assertThat(apercu.getLignes().get(3).getContraventionId()).isEqualTo(12L);

        assertThat(apercu.nombreAReverser()).isEqualTo(2);
        // Total = montants système des lignes A_REVERSER : 5000 + 8000.
        assertThat(apercu.totalAReverser()).isEqualByComparingTo(new BigDecimal("13000"));
    }

    @Test
    void archive_le_document_source() {
        when(extractor.extraire(any())).thenReturn(new QuittanceReversement(
                "LIQ-1", "SOL-1", "X", LocalDate.now(), List.of()));

        useCase.previsualiser(new ByteArrayInputStream("pdf".getBytes()), "q.pdf", "application/pdf");

        verify(fileStoragePort).upload(anyString(), any(InputStream.class), anyLong(), eq("application/pdf"));
    }
}
