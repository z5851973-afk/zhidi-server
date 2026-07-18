-- V16: payment orders, settlements, after-sales

CREATE TABLE payment_orders (
    id BINARY(16) PRIMARY KEY,
    booking_id BINARY(16) NOT NULL,
    owner_user_id BINARY(16) NOT NULL,
    worker_user_id BINARY(16) NOT NULL,
    quote_id BINARY(16) NULL,
    amount DECIMAL(12,2) NOT NULL COMMENT '支付金额（业主已确认报价）',
    platform_fee DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '平台服务费',
    worker_settlement DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '工人结算金额=amount-platform_fee',
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/PAID/CANCELLED/REFUNDED/FAILED',
    payment_method VARCHAR(32) NULL,
    transaction_id VARCHAR(128) NULL COMMENT '第三方支付流水号',
    paid_at DATETIME(6) NULL,
    refunded_at DATETIME(6) NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id)
);

CREATE TABLE settlements (
    id BINARY(16) PRIMARY KEY,
    worker_user_id BINARY(16) NOT NULL,
    booking_id BINARY(16) NOT NULL,
    payment_order_id BINARY(16) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/SETTLEABLE/SETTLED/FROZEN',
    frozen_reason VARCHAR(300) NULL,
    settled_at DATETIME(6) NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id),
    FOREIGN KEY (payment_order_id) REFERENCES payment_orders(id)
);

CREATE TABLE after_sales (
    id BINARY(16) PRIMARY KEY,
    booking_id BINARY(16) NOT NULL,
    owner_user_id BINARY(16) NOT NULL,
    type VARCHAR(32) NOT NULL COMMENT 'REFUND/COMPLAINT/DISPUTE',
    reason TEXT NOT NULL,
    evidence JSON NULL COMMENT '关联的quote_id/inspection_record_ids/chat_message_ids',
    status VARCHAR(32) NOT NULL DEFAULT 'OPEN' COMMENT 'OPEN/PLATFORM_PROCESSING/RESOLVED/CLOSED',
    resolution TEXT NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id)
);
