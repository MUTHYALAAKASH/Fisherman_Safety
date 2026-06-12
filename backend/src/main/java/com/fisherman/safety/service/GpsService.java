package com.fisherman.safety.service;

import com.fisherman.safety.dto.GpsUpdateDto;
import com.fisherman.safety.exception.ResourceNotFoundException;
import com.fisherman.safety.model.GpsLocation;
import com.fisherman.safety.model.User;
import com.fisherman.safety.repository.GpsLocationRepository;
import com.fisherman.safety.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
public class GpsService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private GpsLocationRepository gpsLocationRepository;

    @Transactional
    public GpsLocation saveLocation(String mobileNumber, GpsUpdateDto dto) {
        User user = userRepository.findByMobileNumber(mobileNumber)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with mobile: " + mobileNumber));

        LocalDateTime timestamp = LocalDateTime.now();
        if (dto.getTimestamp() != null && !dto.getTimestamp().isBlank()) {
            try {
                timestamp = LocalDateTime.parse(dto.getTimestamp(), DateTimeFormatter.ISO_DATE_TIME);
            } catch (Exception e) {
                // Fallback to parsed dynamic time
                timestamp = LocalDateTime.now();
            }
        }

        GpsLocation gpsLocation = GpsLocation.builder()
                .user(user)
                .latitude(dto.getLatitude())
                .longitude(dto.getLongitude())
                .speed(dto.getSpeed() != null ? dto.getSpeed() : 0.0)
                .timestamp(timestamp)
                .build();

        return gpsLocationRepository.save(gpsLocation);
    }

    public List<GpsLocation> getLocationHistory(String mobileNumber) {
        User user = userRepository.findByMobileNumber(mobileNumber)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with mobile: " + mobileNumber));

        return gpsLocationRepository.findByUserIdOrderByTimestampAsc(user.getId());
    }
}
