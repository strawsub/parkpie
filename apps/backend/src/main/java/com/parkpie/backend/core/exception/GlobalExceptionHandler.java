package com.parkpie.backend.core.exception;

import jakarta.validation.ConstraintViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Centralised exception handling for REST controllers. The handler converts common validation
 * exceptions into JSON error payloads understood by front-end clients.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * Creates the exception handler.
     */
    public GlobalExceptionHandler() {
    }

    /**
     * Converts {@link MethodArgumentNotValidException} instances raised when request bodies fail to
     * bind to validation constraints.
     *
     * @param exception validation exception raised by Spring MVC
     * @return JSON payload describing the violated fields
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    Map<String, Object> badRequest(MethodArgumentNotValidException exception) {
        return Map.of(
                "error", "validation_failed",
                "details", exception.getBindingResult().getFieldErrors().stream()
                        .map(e -> Map.of("field", e.getField(), "msg", e.getDefaultMessage()))
                        .toList()
        );
    }

    /**
     * Converts bean validation {@link ConstraintViolationException} instances generated for invalid
     * request parameters.
     *
     * @param exception constraint violation thrown by the validation framework
     * @return JSON payload describing the failed constraint
     */
    @ExceptionHandler(ConstraintViolationException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    Map<String, Object> constraintViolation(ConstraintViolationException exception) {
        return Map.of(
                "error", "constraint_violation",
                "message", exception.getMessage()
        );
    }
}
