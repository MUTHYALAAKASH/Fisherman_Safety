package com.fisherman.safety.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SosAlertDto {
    private Long id;
    private Long userId;
    private String fullName;
    private Double latitude;
    private Double longitude;
    private String status;
    private String createdAt;
}
