package com.os.workshop.auth;

import com.amazonaws.services.lambda.runtime.events.APIGatewayCustomAuthorizerEvent;
import com.amazonaws.services.lambda.runtime.events.IamPolicyResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TokenAuthorizerHandlerTest {

    private static final String SECRET = "test-secret-that-is-long-enough-for-hs256-signing!!";
    private static final String METHOD_ARN =
            "arn:aws:execute-api:us-east-1:123456789012:abc123/prod/GET/orders";

    private JwtIssuer issuer;
    private TokenAuthorizerHandler handler;

    @BeforeEach
    void setUp() {
        issuer = new JwtIssuer(SECRET, 86_400_000L);
        handler = new TokenAuthorizerHandler(new JwtVerifier(SECRET));
    }

    private IamPolicyResponse invoke(String authorizationToken) {
        APIGatewayCustomAuthorizerEvent event = new APIGatewayCustomAuthorizerEvent();
        event.setAuthorizationToken(authorizationToken);
        event.setMethodArn(METHOD_ARN);
        return handler.handleRequest(event, null);
    }

    @Test
    void allowsValidTokenAndExposesClaims() {
        String token = issuer.issue("52998224725", new Client(7L, "JOAO", true));

        IamPolicyResponse response = invoke("Bearer " + token);

        assertThat(response.getPrincipalId()).isEqualTo("52998224725");
        assertThat(response.getContext())
                .containsEntry("clientId", "7")
                .containsEntry("name", "JOAO")
                .containsEntry("cpf", "52998224725");
        // Policy document carries a single Allow statement for the requested method ARN.
        assertThat(response.getPolicyDocument())
                .containsEntry("Version", IamPolicyResponse.VERSION_2012_10_17);
        Object[] statements = (Object[]) response.getPolicyDocument().get("Statement");
        assertThat(statements).hasSize(1);
    }

    @Test
    void acceptsTokenWithoutBearerPrefix() {
        String token = issuer.issue("52998224725", new Client(7L, "JOAO", true));
        assertThat(invoke(token).getPrincipalId()).isEqualTo("52998224725");
    }

    @Test
    void rejectsMissingToken() {
        assertThatThrownBy(() -> invoke(null))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("Unauthorized");
    }

    @Test
    void rejectsTokenSignedWithDifferentSecret() {
        String foreign = new JwtIssuer("a-completely-different-secret-value-still-long!!", 86_400_000L)
                .issue("52998224725", new Client(7L, "JOAO", true));

        assertThatThrownBy(() -> invoke("Bearer " + foreign))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("Unauthorized");
    }

    @Test
    void rejectsExpiredToken() {
        String expired = new JwtIssuer(SECRET, -1000L)
                .issue("52998224725", new Client(7L, "JOAO", true));

        assertThatThrownBy(() -> invoke("Bearer " + expired))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("Unauthorized");
    }
}
