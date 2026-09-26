package com.rfscheduler.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * CORS for the Frontend.
 *
 * <p>The Frontend runs on :5173 and the API on :8080 (API_CONTRACT.md Section 7), so every
 * browser call is cross-origin. The default wildcard preserves local demo behavior; a deployment
 * can set RFSCHEDULER_ALLOWED_ORIGINS to its Frontend origin.
 */
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    private final AllowedOrigins allowedOrigins;

    public CorsConfig(AllowedOrigins allowedOrigins) {
        this.allowedOrigins = allowedOrigins;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns(allowedOrigins.patterns())
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*");
        registry.addMapping("/health").allowedOriginPatterns(allowedOrigins.patterns());
        registry.addMapping("/ready").allowedOriginPatterns(allowedOrigins.patterns());
    }
}
