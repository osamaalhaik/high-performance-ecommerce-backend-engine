package com.ecommerce.dto;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class ApiResponseTest {

    @Test
    void okResponseContainsSuccessAndData() {
        ApiResponse<String> response = ApiResponse.ok("done");

        assertTrue(response.isSuccess());
        assertEquals("done", response.getData());
        assertNotEquals(0, response.getTimestamp());
    }

    @Test
    void okResponseWithMessageContainsMessageAndData() {
        ApiResponse<Integer> response = ApiResponse.ok("created", 201);

        assertTrue(response.isSuccess());
        assertEquals("created", response.getMessage());
        assertEquals(201, response.getData());
    }

    @Test
    void errorResponseContainsFailureState() {
        ApiResponse<Void> response = ApiResponse.error("failed");

        assertFalse(response.isSuccess());
        assertEquals("failed", response.getMessage());
        assertNull(response.getData());
    }
}
