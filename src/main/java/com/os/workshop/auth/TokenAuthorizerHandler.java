package com.os.workshop.auth;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayCustomAuthorizerEvent;
import com.amazonaws.services.lambda.runtime.events.IamPolicyResponse;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * API Gateway TOKEN authorizer for protected routes.
 *
 * It does NOT issue tokens — it only validates the JWT produced by {@link JwtIssuer}.
 * On a valid token it returns an Allow IAM policy (with client claims in the context);
 * on an invalid/expired token it throws "Unauthorized", which API Gateway maps to 401.
 */
public class TokenAuthorizerHandler
        implements RequestHandler<APIGatewayCustomAuthorizerEvent, IamPolicyResponse> {

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
    public IamPolicyResponse handleRequest(APIGatewayCustomAuthorizerEvent event, Context context) {
        String token = stripBearer(event.getAuthorizationToken());
        if (token == null) {
            throw new RuntimeException("Unauthorized");
        }

        final Claims claims;
        try {
            claims = jwtVerifier.verify(token);
        } catch (JwtException e) {
            // Invalid signature or expired token -> 401 at the gateway.
            throw new RuntimeException("Unauthorized");
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

        return allow(claims.getSubject(), event.getMethodArn(), authContext);
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

    private static IamPolicyResponse allow(String principalId, String resource,
                                           Map<String, Object> authContext) {
        IamPolicyResponse.Statement statement = IamPolicyResponse.allowStatement(resource);
        IamPolicyResponse.PolicyDocument policyDocument = IamPolicyResponse.PolicyDocument.builder()
                .withVersion(IamPolicyResponse.VERSION_2012_10_17)
                .withStatement(List.of(statement))
                .build();
        return IamPolicyResponse.builder()
                .withPrincipalId(principalId)
                .withPolicyDocument(policyDocument)
                .withContext(authContext)
                .build();
    }
}
