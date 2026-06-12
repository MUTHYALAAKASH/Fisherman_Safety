package com.fisherman.safety.service;

import com.fisherman.safety.dto.UserDto;
import com.fisherman.safety.exception.ResourceNotFoundException;
import com.fisherman.safety.model.Boat;
import com.fisherman.safety.model.EmergencyContact;
import com.fisherman.safety.model.User;
import com.fisherman.safety.repository.BoatRepository;
import com.fisherman.safety.repository.EmergencyContactRepository;
import com.fisherman.safety.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class UserService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BoatRepository boatRepository;

    @Autowired
    private EmergencyContactRepository emergencyContactRepository;

    public User getUserByMobile(String mobileNumber) {
        return userRepository.findByMobileNumber(mobileNumber)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with mobile number: " + mobileNumber));
    }

    public UserDto getUserProfile(String mobileNumber) {
        User user = getUserByMobile(mobileNumber);
        Boat boat = boatRepository.findByUser(user).orElse(null);

        return UserDto.builder()
                .fullName(user.getFullName())
                .mobileNumber(user.getMobileNumber())
                .email(user.getEmail())
                .role(user.getRole().name())
                .profileImageUrl(user.getProfileImageUrl())
                .boatName(boat != null ? boat.getBoatName() : null)
                .registrationNumber(boat != null ? boat.getRegistrationNumber() : null)
                .harborLocation(boat != null ? boat.getHarborLocation() : null)
                .build();
    }

    @Transactional
    public UserDto updateUserProfile(String mobileNumber, UserDto updateDto) {
        User user = getUserByMobile(mobileNumber);

        user.setFullName(updateDto.getFullName());
        if (updateDto.getEmail() != null) {
            user.setEmail(updateDto.getEmail());
        }
        if (updateDto.getProfileImageUrl() != null) {
            user.setProfileImageUrl(updateDto.getProfileImageUrl());
        }

        userRepository.save(user);

        // Update boat details if applicable
        if (updateDto.getBoatName() != null && !updateDto.getBoatName().isBlank()) {
            Boat boat = boatRepository.findByUser(user).orElse(null);
            if (boat == null) {
                boat = Boat.builder().user(user).build();
            }
            boat.setBoatName(updateDto.getBoatName());
            if (updateDto.getRegistrationNumber() != null) {
                boat.setRegistrationNumber(updateDto.getRegistrationNumber());
            }
            boat.setHarborLocation(updateDto.getHarborLocation());
            boatRepository.save(boat);
        }

        return getUserProfile(user.getMobileNumber());
    }

    @Transactional
    public EmergencyContact addEmergencyContact(String mobileNumber, Long contactUserId, String relationship) {
        User user = getUserByMobile(mobileNumber);
        User contactUser = userRepository.findById(contactUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Contact user not found with id: " + contactUserId));

        if (user.getId().equals(contactUserId)) {
            throw new IllegalArgumentException("Cannot add yourself as an emergency contact");
        }

        EmergencyContact contact = EmergencyContact.builder()
                .user(user)
                .contactUser(contactUser)
                .relationship(relationship)
                .build();
        return emergencyContactRepository.save(contact);
    }

    public List<EmergencyContact> getEmergencyContacts(String mobileNumber) {
        User user = getUserByMobile(mobileNumber);
        return emergencyContactRepository.findByUserId(user.getId());
    }

    public List<User> searchUsers(String query) {
        return userRepository.searchUsers(query);
    }
}
