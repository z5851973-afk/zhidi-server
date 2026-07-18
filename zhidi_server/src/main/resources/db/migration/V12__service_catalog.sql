CREATE TABLE service_catalog (
  id BINARY(16) PRIMARY KEY,
  category VARCHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  unit VARCHAR(16) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  is_material BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INT NOT NULL DEFAULT 0,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_service_catalog_category (category),
  CONSTRAINT ck_service_catalog_category
    CHECK (category IN ('PLUMBING','ELECTRICAL','CARPENTRY','PAINTING','MASONRY','DEMOLITION'))
);

-- 水电工 (PLUMBING / ELECTRICAL)
INSERT INTO service_catalog (id, category, name, unit, unit_price, is_material, sort_order, version, created_at, updated_at) VALUES
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000001','-','')), 'PLUMBING',   '水管检修',     '项',   80.00, FALSE, 1, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000002','-','')), 'PLUMBING',   '水管改造',     '米',  120.00, FALSE, 2, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000003','-','')), 'ELECTRICAL', '电路检修',     '项',   80.00, FALSE, 3, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000004','-','')), 'ELECTRICAL', '开关插座安装', '个',   30.00, FALSE, 4, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000005','-','')), 'ELECTRICAL', '灯具安装',     '个',   50.00, FALSE, 5, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000006','-','')), 'ELECTRICAL', '电路改造',     '米',  100.00, FALSE, 6, 0, NOW(6), NOW(6));

-- 木工 (CARPENTRY)
INSERT INTO service_catalog (id, category, name, unit, unit_price, is_material, sort_order, version, created_at, updated_at) VALUES
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000007','-','')), 'CARPENTRY', '门套安装',   '套',   200.00, FALSE, 1, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000008','-','')), 'CARPENTRY', '踢脚线安装', '米',    35.00, FALSE, 2, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000009','-','')), 'CARPENTRY', '吊顶安装',   '平米', 120.00, FALSE, 3, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-00000000000a','-','')), 'CARPENTRY', '柜体安装',   '平米', 300.00, FALSE, 4, 0, NOW(6), NOW(6));

-- 油漆 (PAINTING)
INSERT INTO service_catalog (id, category, name, unit, unit_price, is_material, sort_order, version, created_at, updated_at) VALUES
  (UNHEX(REPLACE('a0000001-0000-0000-0000-00000000000b','-','')), 'PAINTING', '墙面刷漆',   '平米', 40.00, FALSE, 1, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-00000000000c','-','')), 'PAINTING', '天花板刷漆', '平米', 45.00, FALSE, 2, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-00000000000d','-','')), 'PAINTING', '木器刷漆',   '平米', 80.00, FALSE, 3, 0, NOW(6), NOW(6));

-- 泥瓦 (MASONRY)
INSERT INTO service_catalog (id, category, name, unit, unit_price, is_material, sort_order, version, created_at, updated_at) VALUES
  (UNHEX(REPLACE('a0000001-0000-0000-0000-00000000000e','-','')), 'MASONRY', '贴墙砖',   '平米',  80.00, FALSE, 1, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-00000000000f','-','')), 'MASONRY', '贴地砖',   '平米',  80.00, FALSE, 2, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000010','-','')), 'MASONRY', '砌墙',     '平米', 150.00, FALSE, 3, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000011','-','')), 'MASONRY', '防水处理', '平米',  60.00, FALSE, 4, 0, NOW(6), NOW(6));

-- 拆除 (DEMOLITION)
INSERT INTO service_catalog (id, category, name, unit, unit_price, is_material, sort_order, version, created_at, updated_at) VALUES
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000012','-','')), 'DEMOLITION', '墙皮铲除',   '平米',  25.00, FALSE, 1, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000013','-','')), 'DEMOLITION', '瓷砖拆除',   '平米',  45.00, FALSE, 2, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000014','-','')), 'DEMOLITION', '墙体拆除',   '平米', 120.00, FALSE, 3, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000001-0000-0000-0000-000000000015','-','')), 'DEMOLITION', '旧家具拆除', '项',   200.00, FALSE, 4, 0, NOW(6), NOW(6));
