-- V18: warranty retentions

CREATE TABLE warranty_retentions (
    id BINARY(16) PRIMARY KEY,
    worker_user_id BINARY(16) NOT NULL,
    owner_user_id BINARY(16) NOT NULL,
    booking_id BINARY(16) NOT NULL,
    payment_order_id BINARY(16) NOT NULL,
    amount DECIMAL(12,2) NOT NULL COMMENT '原始冻结质保金金额',
    released_amount DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '已释放给工人的质保金金额',
    deducted_amount DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '售后处理已扣减金额',
    status VARCHAR(32) NOT NULL DEFAULT 'HELD' COMMENT 'HELD/RELEASED/DEDUCTED',
    deduction_reason VARCHAR(300) NULL,
    released_at DATETIME(6) NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT uk_warranty_retention_payment_order UNIQUE (payment_order_id),
    FOREIGN KEY (booking_id) REFERENCES bookings(id),
    FOREIGN KEY (payment_order_id) REFERENCES payment_orders(id)
);

CREATE INDEX idx_warranty_retentions_worker_created
    ON warranty_retentions(worker_user_id, created_at);

CREATE INDEX idx_warranty_retentions_owner_created
    ON warranty_retentions(owner_user_id, created_at);
