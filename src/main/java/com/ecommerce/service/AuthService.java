package com.ecommerce.service;

import com.ecommerce.dto.AuthDTOs;
import com.ecommerce.entity.User;
import com.ecommerce.exception.BusinessException;
import com.ecommerce.exception.ResourceNotFoundException;
import com.ecommerce.repository.UserRepository;
import com.ecommerce.security.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;

    @Transactional
    public AuthDTOs.AuthResponse register(
            AuthDTOs.RegisterRequest request
    ) {

        String normalizedEmail = request.getEmail()
                .trim()
                .toLowerCase();

        if (userRepository.existsByEmail(normalizedEmail)) {
            throw new BusinessException(
                    "Email already exists"
            );
        }

        User user = User.builder()
                .email(normalizedEmail)
                .passwordHash(
                        passwordEncoder.encode(request.getPassword())
                )
                .fullName(request.getFullName().trim())
                .role(User.Role.CUSTOMER)
                .build();

        userRepository.save(user);

        String token = jwtService.generateToken(
                user.getEmail(),
                user.getRole().name()
        );

        log.info(
                "[AUTH] User registered: {}",
                user.getEmail()
        );

        return AuthDTOs.AuthResponse.builder()
                .token(token)
                .userId(user.getId())
                .email(user.getEmail())
                .role(user.getRole().name())
                .build();
    }

    public AuthDTOs.AuthResponse login(
            AuthDTOs.LoginRequest request
    ) {

        String normalizedEmail = request.getEmail()
                .trim()
                .toLowerCase();

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        normalizedEmail,
                        request.getPassword()
                )
        );

        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "User not found"
                        )
                );

        String token = jwtService.generateToken(
                user.getEmail(),
                user.getRole().name()
        );

        log.info(
                "[AUTH] User logged in: {}",
                user.getEmail()
        );

        return AuthDTOs.AuthResponse.builder()
                .token(token)
                .userId(user.getId())
                .email(user.getEmail())
                .role(user.getRole().name())
                .build();
    }
}