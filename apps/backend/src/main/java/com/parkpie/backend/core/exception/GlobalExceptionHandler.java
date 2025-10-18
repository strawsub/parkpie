package com.parkpie.backend.core.exception;

import jakarta.validation.ConstraintViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

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

    @ExceptionHandler(ConstraintViolationException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    Map<String, Object> constraintViolation(ConstraintViolationException exception) {
        return Map.of(
                "error", "constraint_violation",
                "message", exception.getMessage()
        );
    }
}
