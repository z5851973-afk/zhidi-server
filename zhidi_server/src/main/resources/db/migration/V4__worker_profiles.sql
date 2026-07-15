CREATE TABLE worker_profiles (
  id BINARY(16) PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  name VARCHAR(80) NULL,
  service_city VARCHAR(80) NOT NULL DEFAULT '成都',
  primary_trade VARCHAR(40) NULL,
  experience_years INT NULL,
  daily_rate DECIMAL(7,2) NULL,
  bio VARCHAR(500) NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_worker_profiles_user UNIQUE (user_id),
  CONSTRAINT fk_worker_profiles_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT ck_worker_profiles_experience CHECK (
    experience_years IS NULL OR (experience_years >= 0 AND experience_years <= 60)
  ),
  CONSTRAINT ck_worker_profiles_daily_rate CHECK (
    daily_rate IS NULL OR (daily_rate >= 1 AND daily_rate <= 99999.99)
  )
);
