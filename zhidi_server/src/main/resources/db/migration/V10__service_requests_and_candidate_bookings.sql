CREATE TABLE service_requests (
  id BINARY(16) PRIMARY KEY,
  owner_user_id BINARY(16) NOT NULL,
  trade VARCHAR(40) NOT NULL,
  service_city VARCHAR(80) NOT NULL,
  service_address VARCHAR(200) NULL,
  remark VARCHAR(500) NULL,
  status VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_service_requests_owner_created (owner_user_id, created_at),
  CONSTRAINT fk_service_requests_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
  CONSTRAINT ck_service_requests_status
    CHECK (status IN ('OPEN', 'COMPARING', 'WORKER_SELECTED', 'CANCELLED'))
);

ALTER TABLE bookings
  ADD COLUMN service_request_id BINARY(16) NULL AFTER id,
  ADD COLUMN cancelled_by VARCHAR(16) NULL,
  ADD COLUMN cancel_reason VARCHAR(300) NULL,
  ADD COLUMN cancelled_at DATETIME(6) NULL;

INSERT INTO service_requests
  (id, owner_user_id, trade, service_city, service_address, remark,
   status, version, created_at, updated_at)
SELECT id, owner_user_id, trade, service_city, service_address, remark,
       'OPEN', 0, created_at, updated_at
FROM bookings;

UPDATE bookings SET service_request_id = id WHERE service_request_id IS NULL;

ALTER TABLE bookings
  MODIFY service_request_id BINARY(16) NOT NULL,
  ADD CONSTRAINT fk_bookings_service_request
    FOREIGN KEY (service_request_id) REFERENCES service_requests(id),
  ADD CONSTRAINT uq_bookings_request_worker
    UNIQUE (service_request_id, worker_user_id);

ALTER TABLE bookings DROP CHECK ck_bookings_status;
ALTER TABLE bookings ADD CONSTRAINT ck_bookings_status CHECK (status IN (
  'PENDING', 'ACCEPTED', 'VISIT_PROPOSED', 'VISIT_SCHEDULED',
  'ARRIVAL_PENDING', 'ON_SITE', 'QUOTE_PENDING', 'READY_TO_START',
  'REJECTED', 'CANCELLED', 'NOT_SELECTED'
));
