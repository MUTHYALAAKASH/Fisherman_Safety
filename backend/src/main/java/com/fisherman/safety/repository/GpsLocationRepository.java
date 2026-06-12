package com.fisherman.safety.repository;

import com.fisherman.safety.model.GpsLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface GpsLocationRepository extends JpaRepository<GpsLocation, Long> {
    List<GpsLocation> findByUserIdOrderByTimestampAsc(Long userId);
    List<GpsLocation> findByUserIdOrderByTimestampDesc(Long userId);
}
