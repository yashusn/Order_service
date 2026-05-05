package com.devops.orderservice.service;

import com.devops.orderservice.dto.OrderDTO;
import com.devops.orderservice.model.Order;
import com.devops.orderservice.repository.OrderRepository;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("OrderService Unit Tests")
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @InjectMocks
    private OrderService orderService;

    private Order sampleOrder;
    private OrderDTO.CreateRequest createRequest;

    @BeforeEach
    void setUp() {
        createRequest = OrderDTO.CreateRequest.builder()
                .customerId("CUST-001")
                .productId("PROD-001")
                .quantity(2)
                .totalPrice(new BigDecimal("199.99"))
                .shippingAddress("123 Main St, Bengaluru")
                .build();

        sampleOrder = Order.builder()
                .id(1L)
                .orderNumber("ORD-ABCD1234")
                .customerId("CUST-001")
                .productId("PROD-001")
                .quantity(2)
                .totalPrice(new BigDecimal("199.99"))
                .status(Order.OrderStatus.PENDING)
                .shippingAddress("123 Main St, Bengaluru")
                .build();
    }

    @Test
    @DisplayName("createOrder - should create and return order")
    void createOrder_Success() {
        when(orderRepository.save(any(Order.class))).thenReturn(sampleOrder);

        OrderDTO.Response response = orderService.createOrder(createRequest);

        assertThat(response).isNotNull();
        assertThat(response.getCustomerId()).isEqualTo("CUST-001");
        assertThat(response.getStatus()).isEqualTo(Order.OrderStatus.PENDING);
        verify(orderRepository, times(1)).save(any(Order.class));
    }

    @Test
    @DisplayName("getOrderById - should throw EntityNotFoundException when not found")
    void getOrderById_NotFound_ThrowsException() {
        when(orderRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> orderService.getOrderById(99L))
                .isInstanceOf(EntityNotFoundException.class)
                .hasMessageContaining("99");
    }

    @Test
    @DisplayName("getOrderById - should return order when found")
    void getOrderById_Found_ReturnsResponse() {
        when(orderRepository.findById(1L)).thenReturn(Optional.of(sampleOrder));

        OrderDTO.Response response = orderService.getOrderById(1L);

        assertThat(response.getId()).isEqualTo(1L);
        assertThat(response.getOrderNumber()).isEqualTo("ORD-ABCD1234");
    }

    @Test
    @DisplayName("updateOrderStatus - PENDING to CONFIRMED should succeed")
    void updateStatus_PendingToConfirmed_Success() {
        when(orderRepository.findById(1L)).thenReturn(Optional.of(sampleOrder));
        when(orderRepository.save(any(Order.class))).thenReturn(sampleOrder);

        orderService.updateOrderStatus(1L, Order.OrderStatus.CONFIRMED);

        verify(orderRepository).save(any(Order.class));
    }

    @Test
    @DisplayName("updateOrderStatus - invalid transition should throw IllegalStateException")
    void updateStatus_InvalidTransition_Throws() {
        sampleOrder.setStatus(Order.OrderStatus.DELIVERED);
        when(orderRepository.findById(1L)).thenReturn(Optional.of(sampleOrder));

        assertThatThrownBy(() -> orderService.updateOrderStatus(1L, Order.OrderStatus.PENDING))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Invalid status transition");
    }

    @Test
    @DisplayName("cancelOrder - SHIPPED order should throw IllegalStateException")
    void cancelOrder_Shipped_ThrowsException() {
        sampleOrder.setStatus(Order.OrderStatus.SHIPPED);
        when(orderRepository.findById(1L)).thenReturn(Optional.of(sampleOrder));

        assertThatThrownBy(() -> orderService.cancelOrder(1L))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Cannot cancel");
    }

    @Test
    @DisplayName("cancelOrder - PENDING order should cancel successfully")
    void cancelOrder_Pending_Success() {
        when(orderRepository.findById(1L)).thenReturn(Optional.of(sampleOrder));
        when(orderRepository.save(any(Order.class))).thenReturn(sampleOrder);

        assertThatCode(() -> orderService.cancelOrder(1L)).doesNotThrowAnyException();
        verify(orderRepository).save(argThat(o -> o.getStatus() == Order.OrderStatus.CANCELLED));
    }
}
