package com.fisherman.safety.controller;

import com.fisherman.safety.dto.AuthRequest;
import com.fisherman.safety.dto.AuthResponse;
import com.fisherman.safety.dto.UserDto;
import com.fisherman.safety.model.User;
import com.fisherman.safety.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Authentication Services", description = "Endpoints for registering and authenticating system users.")
public class AuthController {

    @Autowired
    private AuthService authService;

    @PostMapping("/signup")
    @Operation(summary = "Register a new user", description = "Registers a new account. If user is a fisherman, boat details can also be provisioned dynamically.")
    public ResponseEntity<?> register(@Valid @RequestBody UserDto signupRequest) {
        User registeredUser = authService.registerUser(signupRequest);
        Map<String, Object> response = new HashMap<>();
        response.put("message", "User registered successfully");
        response.put("userId", registeredUser.getId());
        response.put("role", registeredUser.getRole().name());
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    @PostMapping("/signin")
    @Operation(summary = "Authenticate user", description = "Validates user credentials (mobile number and password) and returns a stateless JWT authorization token.")
    public ResponseEntity<AuthResponse> signin(@Valid @RequestBody AuthRequest loginRequest) {
        AuthResponse authResponse = authService.authenticateUser(loginRequest);
        return ResponseEntity.ok(authResponse);
    }
}
