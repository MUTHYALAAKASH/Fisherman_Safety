package com.fisherman.safety.controller;

import com.fisherman.safety.dto.UserDto;
import com.fisherman.safety.model.EmergencyContact;
import com.fisherman.safety.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.stream.Collectors;
import com.fisherman.safety.model.User;

@RestController
@RequestMapping("/api/users")
@Tag(name = "User & Boat Profiles", description = "Endpoints for managing user profile details, boat associations, and emergency contacts.")
public class UserController {

    @Autowired
    private UserService userService;

    private String getAuthenticatedMobile() {
        return SecurityContextHolder.getContext().getAuthentication().getName();
    }

    @GetMapping("/profile")
    @Operation(summary = "Get current profile", description = "Retrieves profile information, including vessel registration details if user is a fisherman.")
    public ResponseEntity<UserDto> getProfile() {
        UserDto profile = userService.getUserProfile(getAuthenticatedMobile());
        return ResponseEntity.ok(profile);
    }

    @PutMapping("/profile")
    @Operation(summary = "Update current profile", description = "Updates profile fields (name, email, boat details) for the currently authenticated user.")
    public ResponseEntity<UserDto> updateProfile(@Valid @RequestBody UserDto updateDto) {
        UserDto updated = userService.updateUserProfile(getAuthenticatedMobile(), updateDto);
        return ResponseEntity.ok(updated);
    }

    @PostMapping("/contacts")
    @Operation(summary = "Add emergency contact by user ID", description = "Adds a registered user as an emergency contact.")
    public ResponseEntity<?> addContact(@RequestBody Map<String, Object> payload) {
        Long contactUserId = Long.valueOf(payload.get("contactUserId").toString());
        String relationship = (String) payload.get("relationship");
        EmergencyContact saved = userService.addEmergencyContact(getAuthenticatedMobile(), contactUserId, relationship);

        Map<String, Object> response = new HashMap<>();
        response.put("id", saved.getId());
        response.put("contactUserId", saved.getContactUser().getId());
        response.put("contactName", saved.getContactUser().getFullName());
        response.put("contactMobile", saved.getContactUser().getMobileNumber());
        response.put("relationship", saved.getRelationship());
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    @GetMapping("/contacts")
    @Operation(summary = "Get emergency contacts", description = "Fetches the list of saved emergency contacts for the currently logged-in user.")
    public ResponseEntity<?> getContacts() {
        List<EmergencyContact> contacts = userService.getEmergencyContacts(getAuthenticatedMobile());
        List<Map<String, Object>> response = contacts.stream().map(c -> {
            Map<String, Object> map = new HashMap<>();
            map.put("id", c.getId());
            map.put("contactUserId", c.getContactUser().getId());
            map.put("contactName", c.getContactUser().getFullName());
            map.put("contactMobile", c.getContactUser().getMobileNumber());
            map.put("relationship", c.getRelationship());
            return map;
        }).collect(Collectors.toList());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/search")
    @Operation(summary = "Search registered user accounts", description = "Searches for registered accounts by name or phone number.")
    public ResponseEntity<?> search(@RequestParam String query) {
        List<User> users = userService.searchUsers(query);
        List<Map<String, Object>> response = users.stream().map(u -> {
            Map<String, Object> map = new HashMap<>();
            map.put("id", u.getId());
            map.put("fullName", u.getFullName());
            map.put("mobileNumber", u.getMobileNumber());
            map.put("email", u.getEmail());
            map.put("role", u.getRole().name());
            return map;
        }).collect(Collectors.toList());
        return ResponseEntity.ok(response);
    }
}
