package com.os.workshop.auth;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;

/**
 * Reads clients from the managed PostgreSQL database.
 * Looks up by the raw-digit CPF stored in clients.document.
 */
public class ClientRepository {

    private final String url;
    private final String username;
    private final String password;

    public ClientRepository(String url, String username, String password) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    /** Builds a repository from environment variables. */
    public static ClientRepository fromEnv() {
        return new ClientRepository(
                requireEnv("DB_URL"),
                requireEnv("DB_USERNAME"),
                requireEnv("DB_PASSWORD"));
    }

    public Optional<Client> findByDocument(String documentDigits) {
        String sql = "SELECT id, name, active FROM clients WHERE document = ?";
        try (Connection conn = DriverManager.getConnection(url, username, password);
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, documentDigits);
            try (ResultSet rs = stmt.executeQuery()) {
                if (!rs.next()) {
                    return Optional.empty();
                }
                return Optional.of(new Client(
                        rs.getLong("id"),
                        rs.getString("name"),
                        rs.getBoolean("active")));
            }
        } catch (SQLException e) {
            throw new RepositoryException("Failed to query client by document", e);
        }
    }

    private static String requireEnv(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Missing required environment variable: " + name);
        }
        return value;
    }

    /** Unchecked wrapper so the handler can map DB failures to a 500. */
    public static class RepositoryException extends RuntimeException {
        public RepositoryException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
