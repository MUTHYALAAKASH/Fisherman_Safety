package com.fisherman.safety.controller;

import com.fisherman.safety.dto.GpsUpdateDto;
import com.fisherman.safety.dto.SosAlertDto;
import com.fisherman.safety.model.SosAlert;
import com.fisherman.safety.service.SosService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.fisherman.safety.model.EmergencyContact;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/sos")
@Tag(name = "Emergency SOS", description = "Endpoints for broadcasting emergency SOS triggers and fetching active incidents for Search and Rescue (SAR).")
public class SosController {

    @Autowired
    private SosService sosService;

    private String getAuthenticatedMobile() {
        return SecurityContextHolder.getContext().getAuthentication().getName();
    }

    @PostMapping("/trigger")
    @Operation(summary = "Trigger emergency SOS alert", description = "Immediately logs an emergency SOS alert at the boat's coordinates and triggers push notifications to family members and admin modules.")
    public ResponseEntity<?> triggerSos(@Valid @RequestBody GpsUpdateDto location) {
        SosAlert alert = sosService.triggerAlert(getAuthenticatedMobile(), location);
        List<EmergencyContact> contacts = sosService.getEmergencyContactsForUser(alert.getUser());

        Map<String, Object> response = new HashMap<>();
        response.put("message", "SOS ALERT TRIGGERED! Authorities and emergency contacts notified.");
        response.put("alertId", alert.getId());
        response.put("status", alert.getStatus());
        response.put("timestamp", alert.getCreatedAt());

        List<Map<String, Object>> notifiedList = contacts.stream().map(c -> {
            Map<String, Object> contactMap = new HashMap<>();
            contactMap.put("contactName", c.getContactUser().getFullName());
            contactMap.put("contactMobile", c.getContactUser().getMobileNumber());
            contactMap.put("relationship", c.getRelationship());
            contactMap.put("deliveryStatus", "SMS_SENT_SIMULATED");
            return contactMap;
        }).collect(Collectors.toList());

        response.put("notifiedContacts", notifiedList);
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    @GetMapping("/active")
    @Operation(summary = "Get active SOS alerts", description = "Fetches the complete active list of SOS emergencies. Primarily used by emergency control towers and SAR ships.")
    public ResponseEntity<List<SosAlertDto>> getActive() {
        List<SosAlertDto> activeAlerts = sosService.getActiveAlerts();
        return ResponseEntity.ok(activeAlerts);
    }

    @PutMapping("/resolve/{id}")
    @Operation(summary = "Mark SOS alert resolved", description = "Marks a specific rescue event as resolved once safety is confirmed.")
    public ResponseEntity<?> resolve(@PathVariable Long id) {
        SosAlert alert = sosService.resolveAlert(id);
        Map<String, Object> response = new HashMap<>();
        response.put("message", "SOS Alert resolved successfully");
        response.put("alertId", alert.getId());
        response.put("status", alert.getStatus());
        return ResponseEntity.ok(response);
    }
}
