package com.rfscheduler.config;

import java.util.Arrays;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Browser origins permitted to use the API and simulation WebSocket. */
@Component
public class AllowedOrigins {

    private final String[] patterns;

    public AllowedOrigins(@Value("${rfscheduler.allowed-origins:*}") String value) {
        patterns = Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .toArray(String[]::new);
        if (patterns.length == 0) {
            throw new IllegalArgumentException("rfscheduler.allowed-origins must contain an origin");
        }
    }

    public String[] patterns() {
        return patterns.clone();
    }
}
