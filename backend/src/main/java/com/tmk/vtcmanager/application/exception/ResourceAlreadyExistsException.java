package com.tmk.vtcmanager.application.exception;

public class ResourceAlreadyExistsException extends RuntimeException {

    public ResourceAlreadyExistsException(String message) {
        super(message);
    }

    public static ResourceAlreadyExistsException of(String entity, String field, Object value) {
        return new ResourceAlreadyExistsException(entity + " avec " + field + " \"" + value + "\" existe déjà");
    }
}