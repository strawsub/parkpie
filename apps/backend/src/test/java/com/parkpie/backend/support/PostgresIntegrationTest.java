package com.parkpie.backend.support;

import org.junit.jupiter.api.Assumptions;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Base test class that provisions a PostGIS-enabled PostgreSQL Testcontainer and wires Spring
 * properties for integration tests.
 */
public abstract class PostgresIntegrationTest {

    private static final PostgreSQLContainer<?> POSTGRES;
    private static final boolean CONTAINER_AVAILABLE;
    private static final String STARTUP_MESSAGE;

    static {
        PostgreSQLContainer<?> container = new PostgreSQLContainer<>(
                DockerImageName.parse("postgis/postgis:16-3.4")
                        .asCompatibleSubstituteFor("postgres")
        )
                .withDatabaseName("parkpie")
                .withUsername("parkpie")
                .withPassword("parkpie")
                .withInitScript("db/postgis-init.sql");

        boolean started = false;
        String message = "Docker container not started";
        try {
            container.start();
            started = true;
            message = "started";
        } catch (Throwable throwable) {
            message = throwable.getMessage() != null ? throwable.getMessage() : throwable.getClass().getName();
        }
        POSTGRES = container;
        CONTAINER_AVAILABLE = started;
        STARTUP_MESSAGE = message;
    }

    /**
     * Registers datasource properties for the running container or skips tests if unavailable.
     *
     * @param registry dynamic property registry provided by Spring Test
     */
    @DynamicPropertySource
    static void overrideDataSourceProps(DynamicPropertyRegistry registry) {
        Assumptions.assumeTrue(CONTAINER_AVAILABLE,
                () -> "PostgreSQL Testcontainer unavailable: " + STARTUP_MESSAGE);
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.datasource.driver-class-name", POSTGRES::getDriverClassName);
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "update");
        registry.add("spring.jpa.properties.hibernate.hbm2ddl.auto", () -> "update");
        registry.add("spring.jpa.show-sql", () -> "false");
        // Hibernate 6 (Spring Boot 3.x) auto-detects PostGIS with PostgreSQLDialect
        registry.add("spring.jpa.properties.hibernate.dialect",
                () -> "org.hibernate.dialect.PostgreSQLDialect");
    }

    /**
     * Indicates whether the container started successfully.
     *
     * @return {@code true} when the Testcontainer is available
     */
    public static boolean isContainerAvailable() {
        return CONTAINER_AVAILABLE;
    }
}
