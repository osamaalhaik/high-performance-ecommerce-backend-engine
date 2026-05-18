package com.ecommerce.exception;

import com.ecommerce.dto.ApiResponse;
import jakarta.persistence.LockTimeoutException;
import jakarta.persistence.PessimisticLockException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.transaction.CannotCreateTransactionException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ApiResponse<Void> handleResourceNotFound(ResourceNotFoundException ex) {
        log.warn("[EXCEPTION] Resource not found: {}", ex.getMessage());
        return ApiResponse.error(ex.getMessage());
    }

    @ExceptionHandler(BusinessException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleBusinessException(BusinessException ex) {
        log.warn("[EXCEPTION] Business error: {}", ex.getMessage());
        return ApiResponse.error(ex.getMessage());
    }

    @ExceptionHandler(InsufficientStockException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ApiResponse<Void> handleInsufficientStock(InsufficientStockException ex) {
        log.warn("[EXCEPTION] Insufficient stock: {}", ex.getMessage());
        return ApiResponse.error(ex.getMessage());
    }

    @ExceptionHandler(OptimisticLockingFailureException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ApiResponse<Void> handleOptimisticLock(OptimisticLockingFailureException ex) {
        log.warn("[EXCEPTION] Optimistic locking conflict: {}", ex.getMessage());

        return ApiResponse.error(
                "Data conflict detected. The resource was modified by another transaction. Please retry."
        );
    }

    @ExceptionHandler({
            PessimisticLockException.class,
            LockTimeoutException.class,
            CannotAcquireLockException.class
    })
    @ResponseStatus(HttpStatus.CONFLICT)
    public ApiResponse<Void> handleLockingFailure(Exception ex) {
        log.warn("[EXCEPTION] Database lock conflict: {}", ex.getMessage());

        return ApiResponse.error(
                "The resource is currently locked by another transaction. Please retry."
        );
    }

    @ExceptionHandler(CannotCreateTransactionException.class)
    @ResponseStatus(HttpStatus.SERVICE_UNAVAILABLE)
    public ApiResponse<Void> handleTransactionFailure(CannotCreateTransactionException ex) {
        log.error("[EXCEPTION] Database transaction failure: {}", ex.getMessage());

        return ApiResponse.error(
                "Database is temporarily unavailable. Please retry later."
        );
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Map<String, String>> handleValidation(MethodArgumentNotValidException ex) {

        Map<String, String> errors = new HashMap<>();

        ex.getBindingResult().getFieldErrors().forEach(error -> {
            String field = normalizeFieldName(error);
            String message = error.getDefaultMessage();
            errors.put(field, message);
        });

        log.warn("[EXCEPTION] Validation failed: {}", errors);

        return ApiResponse.error("Validation failed", errors);
    }

    private String normalizeFieldName(FieldError error) {
        String field = error.getField();

        if (field.contains(".")) {
            return field.substring(field.lastIndexOf(".") + 1);
        }

        return field;
    }

    @ExceptionHandler(BadCredentialsException.class)
    @ResponseStatus(HttpStatus.UNAUTHORIZED)
    public ApiResponse<Void> handleBadCredentials(BadCredentialsException ex) {
        log.warn("[EXCEPTION] Bad credentials");
        return ApiResponse.error("Invalid email or password");
    }

    @ExceptionHandler(AccessDeniedException.class)
    @ResponseStatus(HttpStatus.FORBIDDEN)
    public ApiResponse<Void> handleAccessDenied(AccessDeniedException ex) {
        log.warn("[EXCEPTION] Access denied: {}", ex.getMessage());
        return ApiResponse.error("Access denied");
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ApiResponse<Void> handleGeneral(Exception ex) {
        log.error("[EXCEPTION] Unexpected error: {}", ex.getMessage(), ex);
        return ApiResponse.error("Internal server error");
    }
}