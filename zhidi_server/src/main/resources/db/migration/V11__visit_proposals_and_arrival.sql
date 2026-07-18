CREATE TABLE visit_proposals (
  id BINARY(16) PRIMARY KEY,
  booking_id BINARY(16) NOT NULL,
  proposed_by VARCHAR(16) NOT NULL,
  proposed_time DATETIME(6) NOT NULL,
  status VARCHAR(32) NOT NULL,
  reject_reason VARCHAR(300) NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_visit_proposals_booking (booking_id),
  CONSTRAINT fk_visit_proposals_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT ck_visit_proposals_status CHECK (status IN ('PROPOSED', 'ACCEPTED', 'REJECTED')),
  CONSTRAINT ck_visit_proposals_proposed_by CHECK (proposed_by IN ('OWNER', 'WORKER'))
);

ALTER TABLE bookings
  ADD COLUMN arrival_confirmed_by_owner BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN arrival_confirmed_by_worker BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN on_site_at DATETIME(6) NULL;

ALTER TABLE bookings DROP CHECK ck_bookings_status;
ALTER TABLE bookings ADD CONSTRAINT ck_bookings_status CHECK (status IN (
  'PENDING', 'ACCEPTED', 'VISIT_PROPOSED', 'VISIT_SCHEDULED',
  'ARRIVAL_PENDING', 'ON_SITE', 'QUOTE_PENDING', 'READY_TO_START',
  'REJECTED', 'CANCELLED', 'NOT_SELECTED'
));
