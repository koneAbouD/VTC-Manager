package com.tmk.vtcmanager.interfaces.rest.partenaire.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ReglementFactureRequest(
        @NotNull @Positive BigDecimal montant,
        ModePaiement modePaiement,
        Long compteTresorerieId,
        /** Jour du règlement. Absent = aujourd'hui. */
        LocalDate datePaiement,
        String commentaire
) {}
