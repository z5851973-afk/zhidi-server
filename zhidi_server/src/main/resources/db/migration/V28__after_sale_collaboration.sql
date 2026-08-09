ALTER TABLE after_sales
    ADD COLUMN worker_user_id BINARY(16) NULL AFTER owner_user_id,
    ADD COLUMN accepted_at DATETIME(6) NULL AFTER warranty_deduction_amount,
    ADD COLUMN due_at DATETIME(6) NULL AFTER accepted_at,
    ADD COLUMN resolved_at DATETIME(6) NULL AFTER due_at,
    ADD COLUMN closed_at DATETIME(6) NULL AFTER resolved_at,
    ADD COLUMN last_activity_at DATETIME(6) NULL AFTER closed_at;

UPDATE after_sales a
JOIN bookings b ON b.id = a.booking_id
SET a.worker_user_id = b.worker_user_id,
    a.accepted_at = CASE
        WHEN a.status IN ('PLATFORM_PROCESSING', 'RESOLVED', 'CLOSED')
            THEN a.updated_at ELSE NULL END,
    a.due_at = DATE_ADD(a.created_at, INTERVAL 72 HOUR),
    a.resolved_at = CASE
        WHEN a.status IN ('RESOLVED', 'CLOSED') THEN a.updated_at ELSE NULL END,
    a.closed_at = CASE WHEN a.status = 'CLOSED' THEN a.updated_at ELSE NULL END,
    a.last_activity_at = a.updated_at;

-- The legacy API allowed more than one active ticket for the same booking.
-- Keep the newest one active and archive every older duplicate before the
-- generated unique key is added, so existing production data cannot stop V28.
UPDATE after_sales older
JOIN after_sales newer
  ON newer.booking_id = older.booking_id
 AND newer.status IN ('OPEN', 'PLATFORM_PROCESSING')
 AND older.status IN ('OPEN', 'PLATFORM_PROCESSING')
 AND (
      newer.created_at > older.created_at
      OR (newer.created_at = older.created_at AND HEX(newer.id) > HEX(older.id))
 )
SET older.status = 'CLOSED',
    older.resolution = CASE
      WHEN older.resolution IS NULL OR TRIM(older.resolution) = ''
        THEN '历史重复售后工单已归档，保留同订单最新活动工单'
      ELSE older.resolution
    END,
    older.resolved_at = DATE_ADD(
      GREATEST(older.created_at, older.updated_at), INTERVAL 1 MICROSECOND),
    older.closed_at = DATE_ADD(
      GREATEST(older.created_at, older.updated_at), INTERVAL 2 MICROSECOND),
    older.last_activity_at = DATE_ADD(
      GREATEST(older.created_at, older.updated_at), INTERVAL 2 MICROSECOND);

ALTER TABLE after_sales
    MODIFY COLUMN due_at DATETIME(6) NOT NULL,
    MODIFY COLUMN last_activity_at DATETIME(6) NOT NULL,
    ADD COLUMN active_booking_id BINARY(16)
        GENERATED ALWAYS AS (
            CASE WHEN status IN ('OPEN', 'PLATFORM_PROCESSING')
                THEN booking_id ELSE NULL END
        ) STORED,
    ADD CONSTRAINT fk_after_sales_worker_user
        FOREIGN KEY (worker_user_id) REFERENCES users(id),
    ADD UNIQUE KEY uk_after_sales_one_active_booking (active_booking_id),
    ADD INDEX idx_after_sales_worker_created (worker_user_id, created_at);

UPDATE after_sales
SET evidence = JSON_ARRAY()
WHERE evidence IS NULL;

UPDATE after_sales
SET evidence = JSON_ARRAY(JSON_UNQUOTE(evidence))
WHERE JSON_TYPE(evidence) <> 'ARRAY';

CREATE TABLE after_sale_events (
    id BINARY(16) PRIMARY KEY,
    after_sale_id BINARY(16) NOT NULL,
    actor_user_id BINARY(16) NULL,
    actor_role VARCHAR(24) NOT NULL,
    type VARCHAR(40) NOT NULL,
    content TEXT NULL,
    evidence_urls JSON NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_after_sale_events_ticket
        FOREIGN KEY (after_sale_id) REFERENCES after_sales(id),
    CONSTRAINT fk_after_sale_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users(id),
    UNIQUE KEY uk_after_sale_event_idempotency
        (after_sale_id, idempotency_key),
    INDEX idx_after_sale_events_timeline
        (after_sale_id, created_at, id)
);

INSERT INTO after_sale_events (
    id, after_sale_id, actor_user_id, actor_role, type, content,
    evidence_urls, idempotency_key, version, created_at, updated_at
)
SELECT UUID_TO_BIN(UUID()), a.id, a.owner_user_id, 'OWNER', 'CREATED',
       a.reason, COALESCE(a.evidence, JSON_ARRAY()),
       CONCAT('migration-created:', BIN_TO_UUID(a.id)), 0,
       a.created_at, a.created_at
FROM after_sales a;

INSERT INTO after_sale_events (
    id, after_sale_id, actor_user_id, actor_role, type, content,
    evidence_urls, idempotency_key, version, created_at, updated_at
)
SELECT UUID_TO_BIN(UUID()), a.id, NULL, 'SYSTEM', 'RESOLVED',
       a.resolution, JSON_ARRAY(),
       CONCAT('migration-resolved:', BIN_TO_UUID(a.id)), 0,
       a.resolved_at, a.resolved_at
FROM after_sales a
WHERE a.status IN ('RESOLVED', 'CLOSED') AND a.resolution IS NOT NULL;

INSERT INTO after_sale_events (
    id, after_sale_id, actor_user_id, actor_role, type, content,
    evidence_urls, idempotency_key, version, created_at, updated_at
)
SELECT UUID_TO_BIN(UUID()), a.id, NULL, 'SYSTEM', 'CLOSED',
       '历史售后工单已关闭', JSON_ARRAY(),
       CONCAT('migration-closed:', BIN_TO_UUID(a.id)), 0,
       DATE_ADD(a.closed_at, INTERVAL 1 MICROSECOND),
       DATE_ADD(a.closed_at, INTERVAL 1 MICROSECOND)
FROM after_sales a
WHERE a.status = 'CLOSED';
