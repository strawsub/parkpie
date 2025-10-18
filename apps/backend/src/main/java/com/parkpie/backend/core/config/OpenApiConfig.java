package com.parkpie.backend.core.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Contact;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.info.License;
import io.swagger.v3.oas.annotations.servers.Server;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configures the Springdoc OpenAPI integration for the ParkPie backend. This definition describes
 * global API metadata, server URLs, tag groupings, and the basic authentication scheme used by
 * secured admin endpoints. It also registers grouped document definitions that separate public and
 * administrative API surfaces.
 */
@Configuration
@OpenAPIDefinition(
        info = @Info(
                title = "ParkPie Backend API",
                description = "REST endpoints powering the ParkPie mobile and admin experiences.",
                version = "1.0.0",
                contact = @Contact(
                        name = "ParkPie Engineering",
                        email = "engineering@parkpie.com",
                        url = "https://parkpie.com"
                ),
                license = @License(
                        name = "MIT License",
                        url = "https://opensource.org/license/mit"
                )
        ),
        servers = {
                @Server(
                        description = "Production",
                        url = "https://api.parkpie.com"
                ),
                @Server(
                        description = "Staging",
                        url = "https://staging-api.parkpie.com"
                )
        },
        tags = {
                @Tag(name = "Health", description = "System health probes."),
                @Tag(name = "Parking", description = "Public parking discovery APIs."),
                @Tag(name = "Admin", description = "Administrative tooling for operations staff.")
        }
)
@SecurityScheme(
        name = "basicAuth",
        type = SecuritySchemeType.HTTP,
        scheme = "basic"
)
public class OpenApiConfig {

    /**
     * Creates the OpenAPI configuration.
     */
    public OpenApiConfig() {
    }

    /**
     * Creates the OpenAPI grouping that exposes the health and public parking endpoints.
     *
     * @return Springdoc grouping definition for public APIs
     */
    @Bean
    public GroupedOpenApi publicApi() {
        return GroupedOpenApi.builder()
                .group("public")
                .pathsToMatch("/health/**", "/signs/**")
                .build();
    }

    /**
     * Creates the OpenAPI grouping for administration endpoints which require basic authentication.
     *
     * @return Springdoc grouping definition for administrative APIs
     */
    @Bean
    public GroupedOpenApi adminApi() {
        return GroupedOpenApi.builder()
                .group("admin")
                .pathsToMatch("/admin/**")
                .build();
    }
}
