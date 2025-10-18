package com.parkpie.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Entry point for the ParkPie backend application. Enables component scanning,
 * auto-configuration, and bootstraps all Spring infrastructure required by the service.
 */
@SpringBootApplication
public class ParkPieBackendApplication {

	/**
	 * Creates the application bootstrapper.
	 */
	public ParkPieBackendApplication() {
	}

	/**
	 * Boots the ParkPie backend Spring application.
	 *
	 * @param args raw command-line arguments forwarded to Spring Boot
	 */
	public static void main(String[] args) {
		SpringApplication.run(ParkPieBackendApplication.class, args);
	}

}
