package com.os.workshop.auth;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/** Request body for POST /auth. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record AuthRequest(String cpf) {
}
