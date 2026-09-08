package com.os.workshop.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtVerifierTest {

    private static final String SECRET = "test-secret-that-is-long-enough-for-hs256-signing!!";
    private static final String ISS = "os-management-auth";
    private static final String AUD = "os-management-api";

    @Test
    void verifiesTokenWithMatchingIssuerAndAudience() {
        String token = new JwtIssuer(SECRET, 86_400_000L, ISS, AUD)
                .issue("52998224725", new Client(1L, "JOAO", true));

        Claims claims = new JwtVerifier(SECRET, ISS, AUD).verify(token);

        assertThat(claims.getSubject()).isEqualTo("52998224725");
    }

    @Test
    void rejectsTokenWithWrongAudience() {
        String token = new JwtIssuer(SECRET, 86_400_000L, ISS, "another-api")
                .issue("52998224725", new Client(1L, "JOAO", true));

        assertThatThrownBy(() -> new JwtVerifier(SECRET, ISS, AUD).verify(token))
                .isInstanceOf(JwtException.class);
    }

    @Test
    void rejectsTokenMissingIssuerWhenIssuerIsRequired() {
        String token = new JwtIssuer(SECRET, 86_400_000L).issue("52998224725", new Client(1L, "JOAO", true));

        assertThatThrownBy(() -> new JwtVerifier(SECRET, ISS, null).verify(token))
                .isInstanceOf(JwtException.class);
    }

    @Test
    void staysBackwardCompatibleWhenNoIssuerOrAudienceConfigured() {
        String token = new JwtIssuer(SECRET, 86_400_000L).issue("52998224725", new Client(1L, "JOAO", true));

        Claims claims = new JwtVerifier(SECRET).verify(token);

        assertThat(claims.getSubject()).isEqualTo("52998224725");
    }
}
