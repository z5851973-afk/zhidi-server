-- V20: add fixed-price material items so quotes can separate labor and materials.
INSERT INTO service_catalog
  (id, category, name, unit, unit_price, is_material, sort_order, version, created_at, updated_at)
VALUES
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000001','-','')), 'PLUMBING', '水管材料', '米', 25.00, TRUE, 101, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000002','-','')), 'ELECTRICAL', '电线材料', '米', 8.00, TRUE, 102, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000003','-','')), 'ELECTRICAL', '线管材料', '米', 6.00, TRUE, 103, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000004','-','')), 'CARPENTRY', '板材材料', '张', 180.00, TRUE, 101, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000005','-','')), 'CARPENTRY', '五金配件', '套', 80.00, TRUE, 102, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000006','-','')), 'PAINTING', '乳胶漆材料', '桶', 300.00, TRUE, 101, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000007','-','')), 'PAINTING', '腻子粉材料', '袋', 60.00, TRUE, 102, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000008','-','')), 'MASONRY', '水泥砂浆材料', '袋', 45.00, TRUE, 101, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-000000000009','-','')), 'MASONRY', '瓷砖辅材', '平米', 25.00, TRUE, 102, 0, NOW(6), NOW(6)),
  (UNHEX(REPLACE('a0000020-0000-0000-0000-00000000000a','-','')), 'DEMOLITION', '垃圾清运材料', '项', 120.00, TRUE, 101, 0, NOW(6), NOW(6));
