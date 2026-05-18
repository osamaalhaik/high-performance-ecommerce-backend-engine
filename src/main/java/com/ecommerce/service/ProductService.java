package com.ecommerce.service;

import com.ecommerce.dto.ProductDTOs;
import com.ecommerce.entity.Product;
import com.ecommerce.exception.ResourceNotFoundException;
import com.ecommerce.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class ProductService {

    private final ProductRepository productRepository;

    @Cacheable(value = "products", key = "#id")
    @Transactional(readOnly = true)
    public ProductDTOs.ProductResponse getProductById(String id) {
        log.debug("[CACHE] Product cache miss: {}", id);

        Product product = productRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Product not found: " + id));

        return toResponse(product);
    }

    @Transactional(readOnly = true)
    public Page<ProductDTOs.ProductResponse> getAllProducts(int page, int size) {
        int safeSize = Math.min(size, 100);

        return productRepository
                .findAll(PageRequest.of(page, safeSize, Sort.by("createdAt").descending()))
                .map(this::toResponse);
    }

    @Transactional
    @CacheEvict(value = "products", allEntries = true)
    public ProductDTOs.ProductResponse createProduct(ProductDTOs.CreateProductRequest request) {
        Product product = Product.builder()
                .name(request.getName())
                .description(request.getDescription())
                .price(request.getPrice())
                .stockQuantity(request.getStockQuantity())
                .build();

        Product saved = productRepository.save(product);

        log.info("[PRODUCT] Created product: {} | stock={}", saved.getId(), saved.getStockQuantity());

        return toResponse(saved);
    }

    @Transactional
    @CacheEvict(value = "products", key = "#productId")
    public ProductDTOs.ProductResponse updateStock(String productId, ProductDTOs.UpdateStockRequest request) {
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new ResourceNotFoundException("Product not found: " + productId));

        if (!product.getVersion().equals(request.getVersion())) {
            throw new OptimisticLockingFailureException(
                    "Version conflict. Current=" + product.getVersion() + ", Provided=" + request.getVersion()
            );
        }

        product.setStockQuantity(request.getQuantity());

        Product saved = productRepository.save(product);

        log.info("[STOCK] Product {} stock updated to {}", saved.getId(), saved.getStockQuantity());

        return toResponse(saved);
    }

    @Transactional
    @CacheEvict(value = "products", key = "#id")
    public void deleteProduct(String id) {
        if (!productRepository.existsById(id)) {
            throw new ResourceNotFoundException("Product not found: " + id);
        }

        productRepository.deleteById(id);
        log.info("[PRODUCT] Deleted product: {}", id);
    }

    public ProductDTOs.ProductResponse toResponse(Product product) {
        return ProductDTOs.ProductResponse.builder()
                .id(product.getId())
                .name(product.getName())
                .description(product.getDescription())
                .price(product.getPrice())
                .stockQuantity(product.getStockQuantity())
                .version(product.getVersion())
                .createdAt(product.getCreatedAt())
                .build();
    }
}