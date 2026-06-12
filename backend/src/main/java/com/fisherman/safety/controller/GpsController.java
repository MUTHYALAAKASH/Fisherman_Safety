package com.fisherman.safety.controller;

import com.fisherman.safety.dto.GpsUpdateDto;
import com.fisherman.safety.model.GpsLocation;
import com.fisherman.safety.service.GpsService;
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

@RestController
@RequestMapping("/api/gps")
@Tag(name = "GPS Tracking & Locations", description = "Endpoints for broadcasting real-time vessel telemetry and querying historic paths.")
public class GpsController {

    @Autowired
    private GpsService gpsService;

    private String getAuthenticatedMobile() {
        return SecurityContextHolder.getContext().getAuthentication().getName();
    }

    @PostMapping("/update")
    @Operation(summary = "Upload GPS location", description = "Persists vessel's current GPS location coordinates, speed in knots, and timestamp.")
    public ResponseEntity<?> updateLocation(@Valid @RequestBody GpsUpdateDto gpsUpdate) {
        GpsLocation saved = gpsService.saveLocation(getAuthenticatedMobile(), gpsUpdate);
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Location updated successfully");
        response.put("locationId", saved.getId());
        response.put("timestamp", saved.getTimestamp());
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    @GetMapping("/history")
    @Operation(summary = "Get location history", description = "Fetches the list of all historic tracking points for the authenticated user, ordered chronologically.")
    public ResponseEntity<List<GpsLocation>> getHistory() {
        List<GpsLocation> history = gpsService.getLocationHistory(getAuthenticatedMobile());
        return ResponseEntity.ok(history);
    }
}
