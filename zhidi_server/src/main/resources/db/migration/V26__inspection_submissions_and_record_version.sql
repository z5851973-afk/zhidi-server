CREATE TABLE inspection_submissions (
    id BINARY(16) PRIMARY KEY,
    node_id BINARY(16) NOT NULL,
    worker_user_id BINARY(16) NOT NULL,
    note TEXT NULL,
    photos JSON NULL,
    submission_version INT NOT NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_inspection_submissions_node
        FOREIGN KEY (node_id) REFERENCES inspection_nodes(id),
    CONSTRAINT uk_inspection_submissions_node_version
        UNIQUE KEY (node_id, submission_version)
);

CREATE TABLE inspection_evidence_assets (
    id BINARY(16) PRIMARY KEY,
    booking_id BINARY(16) NOT NULL,
    node_id BINARY(16) NOT NULL,
    uploader_user_id BINARY(16) NOT NULL,
    public_url VARCHAR(700) NOT NULL,
    object_key VARCHAR(512) NOT NULL,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_inspection_evidence_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(id),
    CONSTRAINT fk_inspection_evidence_node
        FOREIGN KEY (node_id) REFERENCES inspection_nodes(id),
    CONSTRAINT fk_inspection_evidence_uploader
        FOREIGN KEY (uploader_user_id) REFERENCES users(id),
    CONSTRAINT uk_inspection_evidence_public_url UNIQUE KEY (public_url),
    CONSTRAINT uk_inspection_evidence_object_key UNIQUE KEY (object_key)
);

-- V14 gave every historical record a default version of 1. Re-rank before
-- adding the unique key so legacy multi-round rows remain deployable.
UPDATE inspection_records AS target
JOIN (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY node_id ORDER BY created_at ASC, id ASC
           ) AS round_number
    FROM inspection_records
) AS ranked ON ranked.id = target.id
SET target.inspection_version = ranked.round_number;

-- Every historical owner decision implies that the worker had submitted the
-- same round, even though V14 did not persist that submission separately.
INSERT INTO inspection_submissions (
    id, node_id, worker_user_id, note, photos, submission_version,
    version, created_at, updated_at
)
SELECT UUID_TO_BIN(UUID()), record.node_id, booking.worker_user_id,
       '历史验收申请（V26迁移回填）', NULL, record.inspection_version,
       0, record.created_at, record.created_at
FROM inspection_records AS record
JOIN inspection_nodes AS node ON node.id = record.node_id
JOIN bookings AS booking ON booking.id = node.booking_id;

-- An INSPECTING legacy node has a pending worker submission without an owner
-- decision. Backfill the currently open round so the first V26 decision is
-- version-compatible instead of returning INSPECTION_ROUND_MISMATCH.
INSERT INTO inspection_submissions (
    id, node_id, worker_user_id, note, photos, submission_version,
    version, created_at, updated_at
)
SELECT UUID_TO_BIN(UUID()), node.id, booking.worker_user_id,
       '历史待验收申请（V26迁移回填）', NULL,
       COALESCE(MAX(record.inspection_version), 0) + 1,
       0, node.updated_at, node.updated_at
FROM inspection_nodes AS node
JOIN bookings AS booking ON booking.id = node.booking_id
LEFT JOIN inspection_records AS record ON record.node_id = node.id
WHERE node.status = 'INSPECTING'
GROUP BY node.id, booking.worker_user_id, node.updated_at;

ALTER TABLE inspection_records
    ADD CONSTRAINT uk_inspection_records_node_version
        UNIQUE KEY (node_id, inspection_version);
