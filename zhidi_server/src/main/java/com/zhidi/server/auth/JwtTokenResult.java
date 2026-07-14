package com.zhidi.server.auth;

public record JwtTokenResult(String accessToken, long expiresInSeconds) {
}
