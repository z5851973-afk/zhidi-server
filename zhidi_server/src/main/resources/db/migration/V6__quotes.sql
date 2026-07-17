CREATE TABLE quotes (
  id BINARY(16) PRIMARY KEY,
  booking_id BINARY(16) NOT NULL,
  worker_user_id BINARY(16) NOT NULL,
  items JSON NOT NULL,
  status VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_quotes_booking (booking_id),
  INDEX idx_quotes_worker_created (worker_user_id, created_at),
  CONSTRAINT fk_quotes_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_quotes_worker FOREIGN KEY (worker_user_id) REFERENCES users(id),
  CONSTRAINT ck_quotes_status CHECK (status IN ('SUBMITTED', 'ACCEPTED', 'REJECTED'))
);
