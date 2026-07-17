SET @worker_name_trade_unique_index := (
  SELECT index_name
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'worker_profiles'
    AND non_unique = 0
  GROUP BY index_name
  HAVING GROUP_CONCAT(column_name ORDER BY seq_in_index) = 'name,primary_trade'
  LIMIT 1
);

SET @drop_worker_name_trade_unique_sql := IF(
  @worker_name_trade_unique_index IS NULL,
  'SELECT 1',
  CONCAT('ALTER TABLE worker_profiles DROP INDEX `',
    REPLACE(@worker_name_trade_unique_index, '`', '``'), '`')
);

PREPARE drop_worker_name_trade_unique_stmt FROM @drop_worker_name_trade_unique_sql;
EXECUTE drop_worker_name_trade_unique_stmt;
DEALLOCATE PREPARE drop_worker_name_trade_unique_stmt;
