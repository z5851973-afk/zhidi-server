CREATE TABLE users (
  id BINARY(16) PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  status VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_users_phone UNIQUE (phone)
);

CREATE TABLE user_roles (
  user_id BINARY(16) NOT NULL,
  role VARCHAR(32) NOT NULL,
  PRIMARY KEY (user_id, role),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE operation_logs (
  id BINARY(16) PRIMARY KEY,
  actor_user_id BINARY(16) NULL,
  action VARCHAR(100) NOT NULL,
  target_type VARCHAR(80) NULL,
  target_id VARCHAR(80) NULL,
  result VARCHAR(32) NOT NULL,
  trace_id VARCHAR(64) NOT NULL,
  detail_json JSON NULL,
  created_at DATETIME(6) NOT NULL,
  INDEX idx_operation_actor_time (actor_user_id, created_at),
  INDEX idx_operation_target (target_type, target_id)
);
