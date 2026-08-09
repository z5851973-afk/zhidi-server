package com.zhidi.server.payment;

import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentReferenceClaimRepository
		extends JpaRepository<PaymentReferenceClaim, String> {
}
