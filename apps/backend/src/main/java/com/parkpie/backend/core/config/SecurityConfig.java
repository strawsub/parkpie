package com.parkpie.backend.core.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Configures application security, including the in-memory administrator account, password encoder,
 * and the primary security filter chain that governs access to public and administrative routes.
 */
@Configuration
public class SecurityConfig {

    @Value("${admin.username:admin}")
    private String adminUsername;

    @Value("${admin.password:changeit}")
    private String adminPassword;

    /**
     * Creates the security configuration.
     */
    public SecurityConfig() {
    }

    /**
     * Provides a {@link UserDetailsService} that exposes the configured administrator account.
     *
     * @param encoder password encoder used to hash the admin password
     * @return in-memory user details manager containing the admin user
     */
    @Bean
    public UserDetailsService userDetailsService(PasswordEncoder encoder) {
        UserDetails admin = User.withUsername(adminUsername)
                .password(encoder.encode(adminPassword))
                .roles("ADMIN")
                .build();
        return new InMemoryUserDetailsManager(admin);
    }

    /**
     * Supplies a BCrypt password encoder used for the admin in-memory credentials.
     *
     * @return password encoder instance
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * Builds the main security filter chain, enforcing authentication for administrative endpoints
     * while allowing public access to health checks and parking APIs.
     *
     * @param http framework security builder
     * @return configured security filter chain
     * @throws Exception if the filter chain fails to build
     */
    @Bean
    public SecurityFilterChain app(HttpSecurity http) throws Exception {
        http
                .authorizeHttpRequests(auth -> auth
                        // Admin UI
                        .requestMatchers("/admin/**").hasRole("ADMIN")
                        // Public / API endpoints
                        .requestMatchers("/health", "/health/**", "/actuator/**").permitAll()
                        .requestMatchers("/signs/**").permitAll()
                        .anyRequest().permitAll()
                )
                .formLogin(login -> login
                        .loginPage("/admin/login")
                        .loginProcessingUrl("/admin/login")
                        .defaultSuccessUrl("/admin", true)
                        .permitAll()
                )
                .logout(logout -> logout
                        .logoutUrl("/logout")
                        .logoutSuccessUrl("/admin/login?logout")
                )
                // Keep CSRF ON for admin forms, OFF for APIs used by Flutter
                .csrf(csrf -> csrf
                        .ignoringRequestMatchers("/signs/**", "/health/**", "/actuator/**")
                )
                // Basic sensible defaults
                .httpBasic(Customizer.withDefaults());

        return http.build();
    }
}
