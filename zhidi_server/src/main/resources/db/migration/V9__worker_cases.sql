CREATE TABLE worker_cases (
  id BINARY(16) PRIMARY KEY,
  worker_user_id BINARY(16) NOT NULL,
  title VARCHAR(120) NOT NULL,
  description VARCHAR(1000) NOT NULL,
  service_city VARCHAR(80) NOT NULL,
  completion_year INT NOT NULL,
  image_urls JSON NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_worker_cases_worker_created (worker_user_id, created_at),
  CONSTRAINT fk_worker_cases_worker FOREIGN KEY (worker_user_id) REFERENCES users(id),
  CONSTRAINT ck_worker_cases_year CHECK (completion_year >= 2000 AND completion_year <= 2100),
  CONSTRAINT ck_worker_cases_images CHECK (JSON_LENGTH(image_urls) BETWEEN 1 AND 6)
);
