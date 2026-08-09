-- V24: split owner offline payments from the worker-funded warranty account.
-- Existing payment amounts remain untouched and are explicitly marked legacy.

ALTER TABLE payment_orders
    ADD COLUMN funding_model VARCHAR(40) NOT NULL
        DEFAULT 'LEGACY_OWNER_RETENTION'
        COMMENT 'LEGACY_OWNER_RETENTION/OFFLINE_SPLIT_V2',
    ADD COLUMN quote_amount DECIMAL(12,2) NULL
        COMMENT 'Accepted quote total before the platform service fee',
    ADD COLUMN construction_payment_status VARCHAR(32) NOT NULL
        DEFAULT 'NOT_REPORTED'
        COMMENT 'NOT_REPORTED/REPORTED/CONFIRMED/REJECTED',
    ADD COLUMN platform_fee_status VARCHAR(32) NOT NULL
        DEFAULT 'NOT_REPORTED'
        COMMENT 'NOT_REPORTED/REPORTED/VERIFIED/REJECTED',
    ADD COLUMN construction_payment_channel VARCHAR(32) NULL,
    ADD COLUMN construction_payment_reference VARCHAR(128) NULL,
    ADD COLUMN construction_reported_at DATETIME(6) NULL,
    ADD COLUMN construction_confirmed_at DATETIME(6) NULL,
    ADD COLUMN platform_fee_channel VARCHAR(32) NULL,
    ADD COLUMN platform_fee_reference VARCHAR(128) NULL,
    ADD COLUMN platform_fee_reported_at DATETIME(6) NULL,
    ADD COLUMN platform_fee_verified_by BINARY(16) NULL,
    ADD COLUMN platform_fee_verified_at DATETIME(6) NULL,
    ADD COLUMN platform_fee_rejection_reason VARCHAR(300) NULL,
    ADD CONSTRAINT uq_payment_construction_reference
        UNIQUE (construction_payment_reference),
    ADD CONSTRAINT uq_payment_platform_fee_reference
        UNIQUE (platform_fee_reference);

CREATE TABLE worker_warranty_accounts (
    id BINARY(16) PRIMARY KEY,
    worker_user_id BINARY(16) NOT NULL,
    effective_balance DECIMAL(12,2) NOT NULL DEFAULT 0,
    deducted_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    released_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    cap_amount DECIMAL(12,2) NOT NULL DEFAULT 10000,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE'
        COMMENT 'ACTIVE/TOP_UP_REQUIRED/RELEASE_PENDING/RELEASED',
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT uq_worker_warranty_account_worker UNIQUE (worker_user_id),
    CONSTRAINT fk_worker_warranty_account_worker
        FOREIGN KEY (worker_user_id) REFERENCES users(id)
);

CREATE TABLE worker_warranty_contributions (
    id BINARY(16) PRIMARY KEY,
    worker_user_id BINARY(16) NOT NULL,
    payment_order_id BINARY(16) NOT NULL,
    booking_id BINARY(16) NOT NULL,
    amount_due DECIMAL(12,2) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'DUE'
        COMMENT 'DUE/REPORTED/VERIFIED/REJECTED',
    payment_channel VARCHAR(32) NULL,
    payment_reference VARCHAR(128) NULL,
    reported_at DATETIME(6) NULL,
    verified_by BINARY(16) NULL,
    verified_at DATETIME(6) NULL,
    rejection_reason VARCHAR(300) NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT uq_worker_warranty_contribution_order UNIQUE (payment_order_id),
    CONSTRAINT uq_worker_warranty_contribution_reference UNIQUE (payment_reference),
    CONSTRAINT fk_worker_warranty_contribution_worker
        FOREIGN KEY (worker_user_id) REFERENCES users(id),
    CONSTRAINT fk_worker_warranty_contribution_payment
        FOREIGN KEY (payment_order_id) REFERENCES payment_orders(id),
    CONSTRAINT fk_worker_warranty_contribution_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(id)
);

CREATE INDEX idx_worker_warranty_contribution_worker_status
    ON worker_warranty_contributions(worker_user_id, status);

CREATE TABLE worker_warranty_ledger_entries (
    id BINARY(16) PRIMARY KEY,
    account_id BINARY(16) NOT NULL,
    worker_user_id BINARY(16) NOT NULL,
    entry_type VARCHAR(32) NOT NULL
        COMMENT 'CONTRIBUTION/DEDUCTION/RELEASE',
    amount DECIMAL(12,2) NOT NULL,
    balance_after DECIMAL(12,2) NOT NULL,
    source_type VARCHAR(40) NOT NULL,
    source_id VARCHAR(80) NOT NULL,
    actor_user_id BINARY(16) NULL,
    detail VARCHAR(300) NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_worker_warranty_ledger_account
        FOREIGN KEY (account_id) REFERENCES worker_warranty_accounts(id),
    CONSTRAINT fk_worker_warranty_ledger_worker
        FOREIGN KEY (worker_user_id) REFERENCES users(id)
);

CREATE INDEX idx_worker_warranty_ledger_worker_created
    ON worker_warranty_ledger_entries(worker_user_id, created_at);
