package com.os.workshop.auth;

import com.amazonaws.services.lambda.runtime.events.APIGatewayV2CustomAuthorizerEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class TokenAuthorizerHandlerTest {

    private static final String SECRET = "test-secret-that-is-long-enough-for-hs256-signing!!";

    private JwtIssuer issuer;
    private TokenAuthorizerHandler handler;

    @BeforeEach
    void setUp() {
        issuer = new JwtIssuer(SECRET, 86_400_000L);
        handler = new TokenAuthorizerHandler(new JwtVerifier(SECRET));
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> invoke(String authorizationHeader) {
        APIGatewayV2CustomAuthorizerEvent event = new APIGatewayV2CustomAuthorizerEvent();
        if (authorizationHeader != null) {
            event.setIdentitySource(List.of(authorizationHeader));
            event.setHeaders(Map.of("authorization", authorizationHeader));
        }
        return (Map<String, Object>) (Map<?, ?>) handler.handleRequest(event, null);
    }

    @Test
    @SuppressWarnings("unchecked")
    void allowsValidTokenAndExposesClaimsInContext() {
        String token = issuer.issue("52998224725", new Client(7L, "JOAO", true));

        Map<String, Object> response = invoke("Bearer " + token);

        assertThat(response).containsEntry("isAuthorized", true);
        Map<String, Object> context = (Map<String, Object>) response.get("context");
        assertThat(context)
                .containsEntry("cpf", "52998224725")
                .containsEntry("clientId", "7")
                .containsEntry("name", "JOAO");
    }

    @Test
    void acceptsTokenWithoutBearerPrefix() {
        String token = issuer.issue("52998224725", new Client(7L, "JOAO", true));
        assertThat(invoke(token)).containsEntry("isAuthorized", true);
    }

    @Test
    void deniesMissingToken() {
        assertThat(invoke(null)).containsEntry("isAuthorized", false);
    }

    @Test
    void deniesTokenSignedWithDifferentSecret() {
        String foreign = new JwtIssuer("a-completely-different-secret-value-still-long!!", 86_400_000L)
                .issue("52998224725", new Client(7L, "JOAO", true));

        assertThat(invoke("Bearer " + foreign)).containsEntry("isAuthorized", false);
    }

    @Test
    void deniesExpiredToken() {
        String expired = new JwtIssuer(SECRET, -1000L)
                .issue("52998224725", new Client(7L, "JOAO", true));

        assertThat(invoke("Bearer " + expired)).containsEntry("isAuthorized", false);
    }

    @Test
    void deniesTokenWithWrongIssuer() {
        JwtIssuer foreignIssuer = new JwtIssuer(SECRET, 86_400_000L, "someone-else", null);
        TokenAuthorizerHandler strict =
                new TokenAuthorizerHandler(new JwtVerifier(SECRET, "os-management-auth", null));

        String token = foreignIssuer.issue("52998224725", new Client(7L, "JOAO", true));

        APIGatewayV2CustomAuthorizerEvent event = new APIGatewayV2CustomAuthorizerEvent();
        event.setIdentitySource(List.of("Bearer " + token));

        assertThat(strict.handleRequest(event, null)).containsEntry("isAuthorized", false);
    }
}
