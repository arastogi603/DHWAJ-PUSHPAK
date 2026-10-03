package com.rfscheduler.config;

import com.rfscheduler.websocket.SimulationWebSocketHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

/**
 * Registers the WebSocket endpoint of API_CONTRACT.md Section 3.
 *
 * <p>Raw WebSocket rather than STOMP, because the contract specifies plain JSON frames with a
 * {@code type} field. Layering STOMP on top would change the wire format the Frontend and the
 * contract both describe.
 */
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final SimulationWebSocketHandler handler;
    private final AllowedOrigins allowedOrigins;

    public WebSocketConfig(SimulationWebSocketHandler handler, AllowedOrigins allowedOrigins) {
        this.handler = handler;
        this.allowedOrigins = allowedOrigins;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(handler, "/ws/v1/simulations/*")
                .setAllowedOriginPatterns(allowedOrigins.patterns());
    }
}
