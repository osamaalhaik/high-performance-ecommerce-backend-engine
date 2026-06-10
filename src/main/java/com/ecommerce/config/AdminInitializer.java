package com.ecommerce.config;

import com.ecommerce.entity.User;
import com.ecommerce.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class AdminInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {

        String adminEmail = "admin@test.com";

        if (userRepository.existsByEmail(adminEmail)) {
            log.info("[ADMIN-INIT] Admin already exists: {}", adminEmail);
            return;
        }

        User admin = User.builder()
                .email(adminEmail)
                .passwordHash(passwordEncoder.encode("Admin123456"))
                .fullName("System Admin")
                .walletBalance(1000000.0)
                .role(User.Role.ADMIN)
                .build();

        userRepository.save(admin);

        log.info("[ADMIN-INIT] Admin created successfully: {}", adminEmail);
    }
}
