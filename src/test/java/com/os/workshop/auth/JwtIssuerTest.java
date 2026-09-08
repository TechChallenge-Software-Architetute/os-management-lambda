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

    private static Claims parse(String token) {
        SecretKey key = Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8));
        return Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
    }

    @Test
    void issuesTokenWithExpectedClaimsAndSignature() {
        JwtIssuer issuer = new JwtIssuer(SECRET, 86_400_000L);
        Client client = new Client(42L, "JOAO DA SILVA", true);

        Claims claims = parse(issuer.issue("52998224725", client));

        assertThat(claims.getSubject()).isEqualTo("52998224725");
        assertThat(claims.get("clientId", Long.class)).isEqualTo(42L);
        assertThat(claims.get("name", String.class)).isEqualTo("JOAO DA SILVA");
        assertThat(claims.get("roles", List.class)).containsExactly("CLIENT");
        assertThat(claims.getExpiration()).isAfter(claims.getIssuedAt());
    }

    @Test
    void omitsIssuerAndAudienceWhenNotConfigured() {
        Claims claims = parse(new JwtIssuer(SECRET, 86_400_000L)
                .issue("52998224725", new Client(1L, "JOAO", true)));

        assertThat(claims.getIssuer()).isNull();
        assertThat(claims.getAudience()).isNullOrEmpty();
    }

    @Test
    void stampsIssuerAndAudienceWhenConfigured() {
        JwtIssuer issuer = new JwtIssuer(SECRET, 86_400_000L, "os-management-auth", "os-management-api");

        Claims claims = parse(issuer.issue("52998224725", new Client(1L, "JOAO", true)));

        assertThat(claims.getIssuer()).isEqualTo("os-management-auth");
        assertThat(claims.getAudience()).containsExactly("os-management-api");
    }
}
