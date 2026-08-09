-- V33: atomically claim split-payment references across both components.
--
-- The two V24 per-column unique constraints cannot prevent the same reference
-- from being inserted concurrently into different component columns. This
-- single primary key is the database-level source of truth for all split
-- construction/platform reference ownership.

CREATE TABLE payment_reference_claims (
    payment_reference VARCHAR(128) PRIMARY KEY,
    payment_order_id BINARY(16) NOT NULL,
    component VARCHAR(32) NOT NULL
        COMMENT 'CONSTRUCTION/PLATFORM_FEE',
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT ck_payment_reference_claim_component
        CHECK (component IN ('CONSTRUCTION', 'PLATFORM_FEE')),
    CONSTRAINT fk_payment_reference_claim_order
        FOREIGN KEY (payment_order_id) REFERENCES payment_orders(id)
);

CREATE INDEX idx_payment_reference_claim_order
    ON payment_reference_claims(payment_order_id, component);

-- UNION ALL deliberately makes migration fail on a historical cross-component
-- duplicate instead of silently assigning an ambiguous owner.
INSERT INTO payment_reference_claims (
    payment_reference, payment_order_id, component, created_at
)
SELECT construction_payment_reference, id, 'CONSTRUCTION',
       COALESCE(construction_reported_at, created_at)
FROM payment_orders
WHERE construction_payment_reference IS NOT NULL
UNION ALL
SELECT platform_fee_reference, id, 'PLATFORM_FEE',
       COALESCE(platform_fee_reported_at, created_at)
FROM payment_orders
WHERE platform_fee_reference IS NOT NULL;
