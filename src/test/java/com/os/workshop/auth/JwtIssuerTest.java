package com.os.workshop.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class JwtIssuerTest {

    private static final String SECRET = "test-secret-that-is-long-enough-for-hs256-signing!!";

    @Test
    void issuesTokenWithExpectedClaimsAndSignature() {
        JwtIssuer issuer = new JwtIssuer(SECRET, 86_400_000L);
        Client client = new Client(42L, "JOAO DA SILVA", true);

        String token = issuer.issue("52998224725", client);

        SecretKey key = Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8));
        Claims claims = Jwts.parser().verifyWith(key).build()
                .parseSignedClaims(token).getPayload();

        assertThat(claims.getSubject()).isEqualTo("52998224725");
        assertThat(claims.get("clientId", Long.class)).isEqualTo(42L);
        assertThat(claims.get("name", String.class)).isEqualTo("JOAO DA SILVA");
        assertThat(claims.get("roles", List.class)).containsExactly("CLIENT");
        assertThat(claims.getExpiration()).isAfter(claims.getIssuedAt());
    }
}
