ALTER TABLE quotes
  ADD COLUMN reject_reason VARCHAR(300) NULL;

ALTER TABLE bookings DROP CHECK ck_bookings_status;
ALTER TABLE bookings ADD CONSTRAINT ck_bookings_status CHECK (status IN (
  'PENDING', 'ACCEPTED', 'VISIT_PROPOSED', 'VISIT_SCHEDULED',
  'ARRIVAL_PENDING', 'ON_SITE', 'QUOTE_PENDING', 'READY_TO_START',
  'REJECTED', 'CANCELLED', 'NOT_SELECTED', 'HIRED'
));

ALTER TABLE service_requests DROP CHECK ck_service_requests_status;
ALTER TABLE service_requests ADD CONSTRAINT ck_service_requests_status
  CHECK (status IN ('OPEN', 'COMPARING', 'WORKER_SELECTED', 'ASSIGNED', 'CANCELLED'));
