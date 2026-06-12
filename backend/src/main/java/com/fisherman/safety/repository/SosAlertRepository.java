package com.fisherman.safety.repository;

import com.fisherman.safety.model.SosAlert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface SosAlertRepository extends JpaRepository<SosAlert, Long> {
    List<SosAlert> findByStatusOrderByCreatedAtDesc(String status);
    List<SosAlert> findByUserIdOrderByCreatedAtDesc(Long userId);
}
