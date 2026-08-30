package com.os.workshop.auth;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.Map;
import java.util.Optional;

/**
 * API Gateway proxy handler for CPF authentication.
 *
 * Flow:
 *   1. Parse CPF from the request body.
 *   2. Validate the CPF (400 on invalid).
 *   3. Look up the client by document (404 when not found).
 *   4. Reject inactive clients (403).
 *   5. Issue and return a JWT (200).
 */
public class AuthHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final ClientRepository clientRepository;
    private final JwtIssuer jwtIssuer;

    /** Used by the Lambda runtime — wires dependencies from environment variables. */
    public AuthHandler() {
        this(ClientRepository.fromEnv(), JwtIssuer.fromEnv());
    }

    /** Used by tests — dependencies injected. */
    public AuthHandler(ClientRepository clientRepository, JwtIssuer jwtIssuer) {
        this.clientRepository = clientRepository;
        this.jwtIssuer = jwtIssuer;
    }

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent event, Context context) {
        AuthRequest request;
        try {
            request = MAPPER.readValue(Optional.ofNullable(event.getBody()).orElse("{}"), AuthRequest.class);
        } catch (Exception e) {
            return error(400, "Invalid request body");
        }

        if (request.cpf() == null || request.cpf().isBlank()) {
            return error(400, "CPF is required");
        }

        Cpf cpf;
        try {
            cpf = new Cpf(request.cpf());
        } catch (IllegalArgumentException e) {
            return error(400, "Invalid CPF");
        }

        Optional<Client> found;
        try {
            found = clientRepository.findByDocument(cpf.getValue());
        } catch (ClientRepository.RepositoryException e) {
            return error(500, "Internal error");
        }

        if (found.isEmpty()) {
            return error(404, "Client not found");
        }

        Client client = found.get();
        if (!client.active()) {
            return error(403, "Client is inactive");
        }

        String token = jwtIssuer.issue(cpf.getValue(), client);
        AuthResponse response = AuthResponse.of(token, jwtIssuer.getExpirationMillis(), client);
        return json(200, response);
    }

    private APIGatewayProxyResponseEvent json(int status, Object body) {
        try {
            return new APIGatewayProxyResponseEvent()
                    .withStatusCode(status)
                    .withHeaders(Map.of("Content-Type", "application/json"))
                    .withBody(MAPPER.writeValueAsString(body));
        } catch (Exception e) {
            return error(500, "Serialization error");
        }
    }

    private APIGatewayProxyResponseEvent error(int status, String message) {
        return new APIGatewayProxyResponseEvent()
                .withStatusCode(status)
                .withHeaders(Map.of("Content-Type", "application/json"))
                .withBody("{\"error\":\"" + message + "\"}");
    }
}
