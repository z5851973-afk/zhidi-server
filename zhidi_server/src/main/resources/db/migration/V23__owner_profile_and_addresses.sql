ALTER TABLE owner_profiles
  ADD COLUMN avatar_url VARCHAR(500) NULL AFTER area,
  ADD COLUMN gender VARCHAR(20) NULL AFTER avatar_url;

CREATE TABLE owner_addresses (
  id BINARY(16) PRIMARY KEY,
  owner_user_id BINARY(16) NOT NULL,
  recipient VARCHAR(80) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  province VARCHAR(80) NOT NULL,
  city VARCHAR(80) NOT NULL,
  district VARCHAR(80) NOT NULL,
  detail VARCHAR(255) NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_owner_addresses_user
    FOREIGN KEY (owner_user_id) REFERENCES users(id),
  INDEX idx_owner_addresses_owner_default_updated
    (owner_user_id, is_default, updated_at)
);
