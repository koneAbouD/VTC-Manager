package com.tmk.vtcmanager.application.exception;

/**
 * Réaffectation refusée pour une raison métier : un arrêté a consigné la
 * créance, la ligne est annulée, un paiement est en cours, ou le chauffeur visé
 * conduisait déjà un autre véhicule ce jour-là.
 *
 * <p>Distincte d'{@link EcritureFigeeException}, qui dit qu'un arrêté de
 * <em>date</em> — période close, caisse comptée — ferme la porte : le client
 * peut ainsi distinguer « les livres sont fermés » de « cette réaffectation-là
 * n'a pas de sens ».
 */
public class ReaffectationImpossibleException extends RuntimeException {

    public ReaffectationImpossibleException(String message) {
        super(message);
    }
}
