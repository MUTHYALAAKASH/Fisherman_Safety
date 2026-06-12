package com.fisherman.safety.service;

import com.fisherman.safety.dto.GpsUpdateDto;
import com.fisherman.safety.dto.SosAlertDto;
import com.fisherman.safety.exception.ResourceNotFoundException;
import com.fisherman.safety.model.EmergencyContact;
import com.fisherman.safety.repository.EmergencyContactRepository;
import com.fisherman.safety.model.SosAlert;
import com.fisherman.safety.model.User;
import com.fisherman.safety.repository.SosAlertRepository;
import com.fisherman.safety.repository.UserRepository;
import com.fisherman.safety.model.ChatMessage;
import com.fisherman.safety.repository.ChatMessageRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class SosService {

    private static final Logger logger = LoggerFactory.getLogger(SosService.class);

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SosAlertRepository sosAlertRepository;

    @Autowired
    private EmergencyContactRepository emergencyContactRepository;

    @Autowired
    private ChatMessageRepository chatMessageRepository;

    @Transactional
    public SosAlert triggerAlert(String mobileNumber, GpsUpdateDto location) {
        User user = userRepository.findByMobileNumber(mobileNumber)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with mobile: " + mobileNumber));

        SosAlert alert = SosAlert.builder()
                .user(user)
                .latitude(location.getLatitude())
                .longitude(location.getLongitude())
                .status("ACTIVE")
                .build();

        SosAlert saved = sosAlertRepository.save(alert);

        // Simulation: Send push notification to family / admin via FCM
        sendFcmNotification(user.getFullName(), alert.getLatitude(), alert.getLongitude());

        // Dispatch emergency messages and save distress chat history
        List<EmergencyContact> contacts = emergencyContactRepository.findByUserId(user.getId());
        logger.warn("🚨 [EMERGENCY SOS DISPATCH] Initiating chat & SMS dispatch simulation for user: {}", user.getFullName());
        if (contacts.isEmpty()) {
            logger.warn("  --> No emergency contacts registered for this user.");
        } else {
            for (EmergencyContact contact : contacts) {
                User contactUser = contact.getContactUser();
                logger.warn("  --> Simulating SMS transmission to {} ({}) - Message: 'EMERGENCY SOS: {} is in danger at [{}, {}].'",
                        contactUser.getFullName(), contactUser.getMobileNumber(), user.getFullName(), alert.getLatitude(), alert.getLongitude());

                // Auto-inject distress message into user's chat box
                ChatMessage distressMsg = ChatMessage.builder()
                        .sender(user)
                        .recipient(contactUser)
                        .message("🚨 EMERGENCY SOS! I am in danger. Coordinates: Lat " + alert.getLatitude() + ", Lon " + alert.getLongitude())
                        .latitude(alert.getLatitude())
                        .longitude(alert.getLongitude())
                        .isSos(true)
                        .build();
                chatMessageRepository.save(distressMsg);
                logger.warn("  --> Auto-sent distress chat message to {} (ID: {})", contactUser.getFullName(), contactUser.getId());
            }
        }

        return saved;
    }

    public List<EmergencyContact> getEmergencyContactsForUser(User user) {
        return emergencyContactRepository.findByUserId(user.getId());
    }

    public List<SosAlertDto> getActiveAlerts() {
        List<SosAlert> active = sosAlertRepository.findByStatusOrderByCreatedAtDesc("ACTIVE");
        return active.stream().map(this::mapToDto).collect(Collectors.toList());
    }

    @Transactional
    public SosAlert resolveAlert(Long alertId) {
        SosAlert alert = sosAlertRepository.findById(alertId)
                .orElseThrow(() -> new ResourceNotFoundException("SOS Alert not found with id: " + alertId));

        alert.setStatus("RESOLVED");
        return sosAlertRepository.save(alert);
    }

    private SosAlertDto mapToDto(SosAlert alert) {
        return SosAlertDto.builder()
                .id(alert.getId())
                .userId(alert.getUser().getId())
                .fullName(alert.getUser().getFullName())
                .latitude(alert.getLatitude())
                .longitude(alert.getLongitude())
                .status(alert.getStatus())
                .createdAt(alert.getCreatedAt().format(DateTimeFormatter.ISO_DATE_TIME))
                .build();
    }

    private void sendFcmNotification(String fishermanName, Double lat, Double lon) {
        // Log push alert. In production, this maps to Firebase Cloud Messaging (FCM).
        logger.warn("🚨 [EMERGENCY PUSH ALERT] Broadcasting SOS alert for fisherman: '{}' at coordinates: [{}, {}]",
                fishermanName, lat, lon);
    }
}
