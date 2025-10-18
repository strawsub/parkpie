package com.parkpie.backend.core.config;

import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Provides geographic helper beans used by spatial queries within the application.
 */
@Configuration
public class GeoConfig {

    /**
     * Creates the configuration.
     */
    public GeoConfig() {
    }

    /**
     * Supplies a {@link GeometryFactory} configured for the WGS84 spatial reference system (SRID 4326).
     *
     * @return geometry factory used to construct spatial objects
     */
    @Bean
    public GeometryFactory geometryFactory() {
        return new GeometryFactory(new PrecisionModel(), 4326); // WGS84
    }
}
