CREATE TABLE bookings (
  id BINARY(16) PRIMARY KEY,
  owner_user_id BINARY(16) NOT NULL,
  worker_user_id BINARY(16) NOT NULL,
  worker_name VARCHAR(80) NOT NULL,
  trade VARCHAR(40) NOT NULL,
  service_city VARCHAR(80) NOT NULL DEFAULT '成都',
  service_address VARCHAR(200) NULL,
  remark VARCHAR(500) NULL,
  status VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_bookings_owner_created (owner_user_id, created_at),
  INDEX idx_bookings_worker_created (worker_user_id, created_at),
  CONSTRAINT fk_bookings_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_bookings_worker FOREIGN KEY (worker_user_id) REFERENCES users(id),
  CONSTRAINT ck_bookings_status CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED'))
);
