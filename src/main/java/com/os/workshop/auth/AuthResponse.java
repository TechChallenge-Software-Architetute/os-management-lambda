package com.os.workshop.auth;

/** Success body for POST /auth. */
public record AuthResponse(String token, long expiresIn, ClientSummary client) {

    public record ClientSummary(long id, String name) {
    }

    public static AuthResponse of(String token, long expiresIn, Client client) {
        return new AuthResponse(token, expiresIn, new ClientSummary(client.id(), client.name()));
    }
}
