package com.fisherman.safety.repository;

import com.fisherman.safety.model.Boat;
import com.fisherman.safety.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface BoatRepository extends JpaRepository<Boat, Long> {
    Optional<Boat> findByUser(User user);
    Optional<Boat> findByUserId(Long userId);
    boolean existsByRegistrationNumber(String registrationNumber);
}
