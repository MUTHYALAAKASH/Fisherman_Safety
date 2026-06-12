package com.fisherman.safety.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;

@Entity
@Table(name = "boats")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Boat {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @NotBlank
    @Size(max = 100)
    @Column(name = "boat_name", nullable = false)
    private String boatName;

    @NotBlank
    @Size(max = 50)
    @Column(name = "registration_number", unique = true, nullable = false)
    private String registrationNumber;

    @Size(max = 100)
    @Column(name = "harbor_location")
    private String harborLocation;
}
