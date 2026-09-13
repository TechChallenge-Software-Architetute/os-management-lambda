package com.os.workshop.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;

/**
 * Verifies JWTs signed by {@link JwtIssuer}.
 * Uses the same shared JWT_SECRET (HS256). Signature and expiration are checked
 * by the jjwt parser; an invalid or expired token throws {@link JwtException}.
 */
public class JwtVerifier {

    private final SecretKey key;

    public JwtVerifier(String secret) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    /** Builds a verifier from the JWT_SECRET environment variable. */
    public static JwtVerifier fromEnv() {
        String secret = System.getenv("JWT_SECRET");
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("Missing required environment variable: JWT_SECRET");
        }
        return new JwtVerifier(secret);
    }

    /**
     * @param token compact JWT (without the "Bearer " prefix)
     * @return the token claims when valid
     * @throws JwtException when the signature is invalid or the token is expired/malformed
     */
    public Claims verify(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
