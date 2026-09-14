package com.tmk.vtcmanager.interfaces.rest.recu;

import com.tmk.vtcmanager.application.usecases.recu.GenererRecuPdfUseCase;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** Reçus de paiement remis aux chauffeurs. */
@RestController
@RequestMapping("/api/recus")
@RequiredArgsConstructor
public class RecuController {

    private final GenererRecuPdfUseCase genererRecuPdfUseCase;

    /**
     * Reçu PDF des écritures données : celles d'un versement, ou toutes celles
     * qu'un chauffeur a réglées d'un même geste — {@code /api/recus/501,502/pdf}.
     */
    @GetMapping("/{operationIds}/pdf")
    public ResponseEntity<byte[]> pdf(@PathVariable List<Long> operationIds) {
        byte[] pdf = genererRecuPdfUseCase.executer(operationIds);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=recu.pdf")
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdf);
    }
}
