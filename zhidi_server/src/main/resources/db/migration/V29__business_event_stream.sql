CREATE TABLE business_event_streams (
    recipient_user_id BINARY(16) NOT NULL PRIMARY KEY,
    last_sequence BIGINT UNSIGNED NOT NULL DEFAULT 0
);

CREATE TABLE business_events (
    event_id BINARY(16) NOT NULL PRIMARY KEY,
    recipient_user_id BINARY(16) NOT NULL,
    sequence_no BIGINT UNSIGNED NOT NULL,
    actor_user_id BINARY(16) NULL,
    event_type VARCHAR(64) NOT NULL,
    aggregate_type VARCHAR(32) NOT NULL,
    aggregate_id BINARY(16) NOT NULL,
    booking_id BINARY(16) NOT NULL,
    service_request_id BINARY(16) NOT NULL,
    idempotency_key VARCHAR(191) NOT NULL,
    payload JSON NULL,
    occurred_at DATETIME(6) NOT NULL,
    read_at DATETIME(6) NULL,
    UNIQUE KEY uk_business_events_recipient_sequence
        (recipient_user_id, sequence_no),
    UNIQUE KEY uk_business_events_recipient_idempotency
        (recipient_user_id, idempotency_key),
    KEY idx_business_events_recipient_cursor
        (recipient_user_id, sequence_no)
);
