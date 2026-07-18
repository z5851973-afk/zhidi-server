-- 聊天室（一个 booking 一个聊天室）
CREATE TABLE chat_rooms (
    id BINARY(16) PRIMARY KEY,
    booking_id BINARY(16) NOT NULL UNIQUE,
    owner_user_id BINARY(16) NOT NULL,
    worker_user_id BINARY(16) NOT NULL,
    last_message_text VARCHAR(500) NULL,
    last_message_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    version BIGINT NOT NULL DEFAULT 0,
    FOREIGN KEY (booking_id) REFERENCES bookings(id)
);

-- 消息表
CREATE TABLE chat_messages (
    id BINARY(16) PRIMARY KEY,
    room_id BINARY(16) NOT NULL,
    sender_user_id BINARY(16) NOT NULL,
    sender_role VARCHAR(16) NOT NULL,
    type VARCHAR(16) NOT NULL DEFAULT 'TEXT',
    content TEXT NOT NULL,
    image_url VARCHAR(500) NULL,
    read_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL,
    version BIGINT NOT NULL DEFAULT 0,
    FOREIGN KEY (room_id) REFERENCES chat_rooms(id),
    INDEX idx_room_created (room_id, created_at)
);

-- 插入默认管理员账号（如不存在）
INSERT INTO users (id, phone, status, created_at, updated_at, version)
SELECT UNHEX(REPLACE('00000000-0000-0000-0000-000000000001', '-', '')),
       '13800000000', 'ACTIVE', NOW(6), NOW(6), 0
WHERE NOT EXISTS (SELECT 1 FROM users WHERE phone = '13800000000');

INSERT INTO user_roles (user_id, role)
SELECT UNHEX(REPLACE('00000000-0000-0000-0000-000000000001', '-', '')),
       'ADMIN'
WHERE NOT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN users u ON ur.user_id = u.id
    WHERE u.phone = '13800000000' AND ur.role = 'ADMIN'
);
