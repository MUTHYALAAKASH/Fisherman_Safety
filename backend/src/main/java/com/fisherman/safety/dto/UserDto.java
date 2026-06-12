package com.fisherman.safety.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserDto {
    @NotBlank(message = "Full name is required")
    @Size(max = 100)
    private String fullName;

    @NotBlank(message = "Mobile number is required")
    @Size(max = 15)
    private String mobileNumber;

    @Email(message = "Invalid email format")
    @Size(max = 100)
    private String email;

    @Size(max = 255)
    private String password; // Only used on registration

    private String role; // FISHERMAN, FAMILY, ADMIN

    private String profileImageUrl;

    // Optional Boat parameters for inline provisioning during signup
    private String boatName;
    private String registrationNumber;
    private String harborLocation;
}
