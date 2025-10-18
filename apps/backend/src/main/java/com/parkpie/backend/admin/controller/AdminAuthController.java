package com.parkpie.backend.admin.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Serves the login page for the administrative console.
 */
@Controller
public class AdminAuthController {

    /**
     * Creates the controller.
     */
    public AdminAuthController() {
    }

    /**
     * Renders the administrative login page.
     *
     * @return template name for the admin login view
     */
    @GetMapping("/admin/login")
    public String login() {
        return "admin/login";
    }
}
