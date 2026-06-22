package com.tmk.vtcmanager.application.exception;

public class RoleInsufficientException extends RuntimeException {

    public RoleInsufficientException(String userId, String requiredRole) {
        super("L'utilisateur '" + userId + "' ne possède pas le rôle requis : " + requiredRole);
    }
}