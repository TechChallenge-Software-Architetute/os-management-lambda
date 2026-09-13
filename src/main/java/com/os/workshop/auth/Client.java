package com.os.workshop.auth;

/** Minimal client projection needed for authentication. */
public record Client(long id, String name, boolean active) {
}
