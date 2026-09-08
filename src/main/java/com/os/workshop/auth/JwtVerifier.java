package com.os.workshop.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.JwtParserBuilder;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;

/**
 * Verifies JWTs signed by {@link JwtIssuer}.
 * Uses the same shared JWT_SECRET (HS256). Signature and expiration are checked
 * by the jjwt parser; an invalid or expired token throws {@link JwtException}.
 *
 * <p>When {@code JWT_ISSUER} / {@code JWT_AUDIENCE} are configured, tokens whose
 * {@code iss} / {@code aud} do not match are rejected as well.
 */
public class JwtVerifier {

    private final SecretKey key;
    private final String expectedIssuer;
    private final String expectedAudience;

    public JwtVerifier(String secret) {
        this(secret, null, null);
    }

    public JwtVerifier(String secret, String expectedIssuer, String expectedAudience) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expectedIssuer = blankToNull(expectedIssuer);
        this.expectedAudience = blankToNull(expectedAudience);
    }

    /** Builds a verifier from environment variables (JWT_SECRET required, others optional). */
    public static JwtVerifier fromEnv() {
        String secret = System.getenv("JWT_SECRET");
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("Missing required environment variable: JWT_SECRET");
        }
        return new JwtVerifier(secret, System.getenv("JWT_ISSUER"), System.getenv("JWT_AUDIENCE"));
    }

    /**
     * @param token compact JWT (without the "Bearer " prefix)
     * @return the token claims when valid
     * @throws JwtException when the signature is invalid, the token is expired/malformed,
     *                      or the issuer/audience does not match the expected value
     */
    public Claims verify(String token) {
        JwtParserBuilder parser = Jwts.parser().verifyWith(key);
        if (expectedIssuer != null) {
            parser.requireIssuer(expectedIssuer);
        }
        if (expectedAudience != null) {
            parser.requireAudience(expectedAudience);
        }
        return parser.build().parseSignedClaims(token).getPayload();
    }

    private static String blankToNull(String value) {
        return (value == null || value.isBlank()) ? null : value;
    }
}
