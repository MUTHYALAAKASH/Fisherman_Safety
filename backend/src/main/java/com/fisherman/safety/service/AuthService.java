package com.fisherman.safety.service;

import com.fisherman.safety.dto.AuthRequest;
import com.fisherman.safety.dto.AuthResponse;
import com.fisherman.safety.dto.UserDto;
import com.fisherman.safety.model.Boat;
import com.fisherman.safety.model.Role;
import com.fisherman.safety.model.User;
import com.fisherman.safety.repository.BoatRepository;
import com.fisherman.safety.repository.UserRepository;
import com.fisherman.safety.security.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BoatRepository boatRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private AuthenticationManager authenticationManager;

    @Autowired
    private JwtUtil jwtUtil;

    @Transactional
    public User registerUser(UserDto signupRequest) {
        if (userRepository.existsByMobileNumber(signupRequest.getMobileNumber())) {
            throw new IllegalArgumentException("Mobile number is already registered!");
        }
        if (signupRequest.getEmail() != null && !signupRequest.getEmail().isBlank()
                && userRepository.existsByEmail(signupRequest.getEmail())) {
            throw new IllegalArgumentException("Email is already registered!");
        }

        Role parsedRole = Role.FISHERMAN;
        if (signupRequest.getRole() != null) {
            try {
                parsedRole = Role.valueOf(signupRequest.getRole().toUpperCase());
            } catch (IllegalArgumentException e) {
                throw new IllegalArgumentException("Invalid Role: " + signupRequest.getRole());
            }
        }

        User user = User.builder()
                .fullName(signupRequest.getFullName())
                .mobileNumber(signupRequest.getMobileNumber())
                .email(signupRequest.getEmail())
                .passwordHash(passwordEncoder.encode(signupRequest.getPassword()))
                .role(parsedRole)
                .profileImageUrl(signupRequest.getProfileImageUrl())
                .build();

        User savedUser = userRepository.save(user);

        // Provision boat if boat details are provided and user is a fisherman
        if (parsedRole == Role.FISHERMAN && signupRequest.getBoatName() != null && !signupRequest.getBoatName().isBlank()) {
            if (signupRequest.getRegistrationNumber() == null || signupRequest.getRegistrationNumber().isBlank()) {
                throw new IllegalArgumentException("Registration number is required to register a boat!");
            }
            if (boatRepository.existsByRegistrationNumber(signupRequest.getRegistrationNumber())) {
                throw new IllegalArgumentException("Boat registration number is already in use!");
            }

            Boat boat = Boat.builder()
                    .user(savedUser)
                    .boatName(signupRequest.getBoatName())
                    .registrationNumber(signupRequest.getRegistrationNumber())
                    .harborLocation(signupRequest.getHarborLocation())
                    .build();

            boatRepository.save(boat);
        }

        return savedUser;
    }

    public AuthResponse authenticateUser(AuthRequest loginRequest) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(loginRequest.getMobileNumber(), loginRequest.getPassword())
        );

        UserDetails userDetails = (UserDetails) authentication.getPrincipal();
        String jwt = jwtUtil.generateToken(userDetails);

        User user = userRepository.findByMobileNumber(loginRequest.getMobileNumber())
                .orElseThrow(() -> new IllegalArgumentException("User not found after authentication!"));

        return AuthResponse.builder()
                .token(jwt)
                .fullName(user.getFullName())
                .mobileNumber(user.getMobileNumber())
                .role(user.getRole().name())
                .build();
    }
}
