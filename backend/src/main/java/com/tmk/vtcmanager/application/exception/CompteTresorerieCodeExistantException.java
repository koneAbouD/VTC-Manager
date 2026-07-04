package com.tmk.vtcmanager.application.exception;

public class CompteTresorerieCodeExistantException extends RuntimeException {

    public CompteTresorerieCodeExistantException(String code) {
        super("Un compte de trésorerie existe déjà avec le code " + code);
    }
}
