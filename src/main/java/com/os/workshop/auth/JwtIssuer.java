package com.os.workshop.auth;

import io.jsonwebtoken.JwtBuilder;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.List;

/**
 * Issues JWTs for authenticated clients.
 * Signs with HS256 using the shared JWT_SECRET so the tokens are verifiable
 * by the same secret configured across the platform (API Gateway authorizer / main app).
 *
 * <p>When {@code JWT_ISSUER} / {@code JWT_AUDIENCE} are configured, they are stamped as the
 * {@code iss} / {@code aud} claims so a token minted here cannot be confused with any other
 * HS256 token that happens to share the secret. {@link JwtVerifier} enforces the same values.
 */
public class JwtIssuer {

    private final SecretKey key;
    private final long expirationMillis;
    private final String issuer;
    private final String audience;

    public JwtIssuer(String secret, long expirationMillis) {
        this(secret, expirationMillis, null, null);
    }

    public JwtIssuer(String secret, long expirationMillis, String issuer, String audience) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMillis = expirationMillis;
        this.issuer = blankToNull(issuer);
        this.audience = blankToNull(audience);
    }

    /** Builds an issuer from environment variables (JWT_SECRET required, others optional). */
    public static JwtIssuer fromEnv() {
        String secret = System.getenv("JWT_SECRET");
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("Missing required environment variable: JWT_SECRET");
        }
        String expiration = System.getenv("JWT_EXPIRATION");
        long expirationMillis = (expiration == null || expiration.isBlank())
                ? 86_400_000L
                : Long.parseLong(expiration);
        return new JwtIssuer(secret, expirationMillis,
                System.getenv("JWT_ISSUER"), System.getenv("JWT_AUDIENCE"));
    }

    /**
     * @param cpf    normalized CPF digits, used as the token subject
     * @param client the authenticated client
     * @return signed compact JWT
     */
    public String issue(String cpf, Client client) {
        long now = System.currentTimeMillis();
        JwtBuilder builder = Jwts.builder()
                .subject(cpf)
                .claim("clientId", client.id())
                .claim("name", client.name())
                .claim("roles", List.of("CLIENT"))
                .issuedAt(new Date(now))
                .expiration(new Date(now + expirationMillis));
        if (issuer != null) {
            builder = builder.issuer(issuer);
        }
        if (audience != null) {
            builder = builder.audience().single(audience);
        }
        return builder.signWith(key).compact();
    }

    public long getExpirationMillis() {
        return expirationMillis;
    }

    private static String blankToNull(String value) {
        return (value == null || value.isBlank()) ? null : value;
    }
}
