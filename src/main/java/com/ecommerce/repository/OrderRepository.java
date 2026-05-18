package com.ecommerce.repository;

import com.ecommerce.entity.Order;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface OrderRepository extends JpaRepository<Order, String> {

    List<Order> findByUserId(String userId);

    @Query("""
           SELECT o FROM Order o
           WHERE o.createdAt BETWEEN :start AND :end
           AND o.status = 'CONFIRMED'
           """)
    List<Order> findConfirmedOrdersBetween(
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end
    );

    @Query("SELECT COUNT(o) FROM Order o WHERE o.createdAt >= :since")
    long countOrdersSince(@Param("since") LocalDateTime since);

    @Query("""
           SELECT COALESCE(SUM(o.totalAmount), 0)
           FROM Order o
           WHERE o.status = 'CONFIRMED'
           AND o.createdAt >= :since
           """)
    Double sumRevenueSince(@Param("since") LocalDateTime since);
}