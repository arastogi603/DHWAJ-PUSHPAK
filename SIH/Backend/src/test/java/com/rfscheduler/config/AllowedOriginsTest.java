package com.rfscheduler.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.config.annotation.CorsRegistry;

class AllowedOriginsTest {

    @Test
    void restrictsApiCorsToConfiguredOrigins() {
        var origins = new AllowedOrigins(" https://demo.vercel.app,https://preview.vercel.app ");
        var registry = new InspectableCorsRegistry();
        new CorsConfig(origins).addCorsMappings(registry);

        assertThat(origins.patterns()).containsExactly(
                "https://demo.vercel.app", "https://preview.vercel.app");
        assertThat(registry.apiOrigins())
                .containsExactly("https://demo.vercel.app", "https://preview.vercel.app");
    }

    @Test
    void defaultWildcardRemainsAvailableForLocalDevelopment() {
        assertThat(new AllowedOrigins("*").patterns()).containsExactly("*");
        assertThatThrownBy(() -> new AllowedOrigins(" , "))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private static class InspectableCorsRegistry extends CorsRegistry {
        List<String> apiOrigins() {
            return getCorsConfigurations().get("/api/**").getAllowedOriginPatterns();
        }
    }
}
