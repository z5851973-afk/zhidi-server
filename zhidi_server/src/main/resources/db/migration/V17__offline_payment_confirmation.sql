-- V17: honest offline-payment confirmation flow.
-- The platform does not claim to hold or transfer money without a payment provider.

ALTER TABLE payment_orders
    ADD COLUMN owner_reported_paid_at DATETIME(6) NULL AFTER paid_at,
    ADD COLUMN offline_payment_channel VARCHAR(32) NULL AFTER owner_reported_paid_at,
    ADD COLUMN payment_reference VARCHAR(128) NULL AFTER offline_payment_channel,
    ADD COLUMN owner_payment_note VARCHAR(300) NULL AFTER payment_reference,
    ADD COLUMN worker_confirmed_received_at DATETIME(6) NULL AFTER owner_payment_note;

ALTER TABLE payment_orders
    MODIFY COLUMN status VARCHAR(32) NOT NULL DEFAULT 'PENDING'
        COMMENT 'PENDING/OWNER_REPORTED_PAID/PAID/CANCELLED/REFUNDED/FAILED';
