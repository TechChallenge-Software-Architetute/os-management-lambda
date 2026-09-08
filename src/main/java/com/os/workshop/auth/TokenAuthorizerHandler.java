package com.os.workshop.auth;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2CustomAuthorizerEvent;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * API Gateway (HTTP API v2) REQUEST authorizer for protected routes.
 *
 * <p>It returns a <b>simple response</b> ({@code {"isAuthorized": <bool>, "context": {...}}})
 * rather than an IAM policy. A simple response is not scoped to a single method ARN, so the
 * gateway can keep authorizer result caching enabled without the classic bug where the first
 * route's per-method policy gets cached and every <i>other</i> route with the same token is
 * then denied (403).
 *
 * <p>It does NOT issue tokens — it only validates the JWT produced by {@link JwtIssuer}.
 * On a valid token it returns {@code isAuthorized = true} plus the client claims in the
 * authorizer context (available to the backend as {@code $context.authorizer.*}); on any
 * invalid/expired/missing token it returns {@code isAuthorized = false}, which the gateway
 * maps to 403.
 */
public class TokenAuthorizerHandler
        implements RequestHandler<APIGatewayV2CustomAuthorizerEvent, Map<String, Object>> {

    private static final Map<String, Object> DENY = Map.of("isAuthorized", false);

    private final JwtVerifier jwtVerifier;

    /** Used by the Lambda runtime. */
    public TokenAuthorizerHandler() {
        this(JwtVerifier.fromEnv());
    }

    /** Used by tests. */
    public TokenAuthorizerHandler(JwtVerifier jwtVerifier) {
        this.jwtVerifier = jwtVerifier;
    }

    @Override
    public Map<String, Object> handleRequest(APIGatewayV2CustomAuthorizerEvent event, Context context) {
        String token = stripBearer(extractAuthorization(event));
        if (token == null) {
            return DENY;
        }

        final Claims claims;
        try {
            claims = jwtVerifier.verify(token);
        } catch (JwtException e) {
            // Invalid signature, expired token, or issuer/audience mismatch -> 403 at the gateway.
            return DENY;
        }

        Map<String, Object> authContext = new HashMap<>();
        authContext.put("cpf", claims.getSubject());
        Object clientId = claims.get("clientId");
        if (clientId != null) {
            authContext.put("clientId", String.valueOf(clientId));
        }
        Object name = claims.get("name");
        if (name != null) {
            authContext.put("name", String.valueOf(name));
        }

        Map<String, Object> response = new HashMap<>();
        response.put("isAuthorized", true);
        response.put("context", authContext);
        return response;
    }

    /** Reads the Authorization value from the configured identity source, falling back to headers. */
    private static String extractAuthorization(APIGatewayV2CustomAuthorizerEvent event) {
        List<String> identitySource = event.getIdentitySource();
        if (identitySource != null && !identitySource.isEmpty() && identitySource.get(0) != null) {
            return identitySource.get(0);
        }
        Map<String, String> headers = event.getHeaders();
        if (headers == null) {
            return null;
        }
        // HTTP API v2 lower-cases header names; stay tolerant of both.
        String value = headers.get("authorization");
        return value != null ? value : headers.get("Authorization");
    }

    private static String stripBearer(String header) {
        if (header == null || header.isBlank()) {
            return null;
        }
        String trimmed = header.trim();
        if (trimmed.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return trimmed.substring(7).trim();
        }
        return trimmed;
    }
}
