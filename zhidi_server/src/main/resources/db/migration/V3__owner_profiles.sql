CREATE TABLE owner_profiles (
  id BINARY(16) PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  name VARCHAR(80) NULL,
  city VARCHAR(80) NOT NULL DEFAULT '成都',
  decoration_type VARCHAR(40) NULL,
  address VARCHAR(255) NULL,
  area DECIMAL(7,2) NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_owner_profiles_user UNIQUE (user_id),
  CONSTRAINT fk_owner_profiles_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT ck_owner_profiles_area CHECK (area IS NULL OR (area >= 1 AND area <= 99999.99))
);
