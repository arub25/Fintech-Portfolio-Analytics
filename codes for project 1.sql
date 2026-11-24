create database fintech_portfolio;
use fintech_portfolio;
show databases;
create table clients (
clients_id VARCHAR(30),
client_segment VARCHAR(30),
region VARCHAR(40),
onboarding_date DATE
);
CREATE TABLE assets (
    asset_id VARCHAR(10) PRIMARY KEY,
    asset_name VARCHAR(100),
    asset_class VARCHAR(40),
    currency VARCHAR(5)
);

SHOW CREATE TABLE clients;

SHOW CREATE TABLE assets;
SHOW TABLE STATUS
WHERE Name IN ('clients', 'assets');
DESCRIBE fintech_portfolio.clients;
DESCRIBE assets;
DESCRIBE transactions;
SELECT
    clients_id,
    COUNT(*) AS occurrences
FROM clients
GROUP BY clients_id
HAVING COUNT(*) > 1;
SELECT *
FROM clients
WHERE clients_id IS NULL OR clients_id = '';
ALTER TABLE clients
ADD PRIMARY KEY (clients_id);
DESCRIBE clients;
USE fintech_portfolio;
DESCRIBE clients;
DESCRIBE assets;
DROP TABLE IF EXISTS transactions;

CREATE TABLE transactions (
    transaction_id VARCHAR(12) PRIMARY KEY,
    client_id VARCHAR(30),
    asset_id VARCHAR(10),
    transaction_date DATE,
    transaction_type VARCHAR(20),
    units DECIMAL(18,6),
    unit_price DECIMAL(18,2),
    gross_amount DECIMAL(18,2),
    fee_amount DECIMAL(18,2),
    transaction_status VARCHAR(20),

    FOREIGN KEY (client_id) REFERENCES clients(clients_id),
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id)
);

SHOW TABLES;
DESCRIBE transactions;


 ## 1. Validate table volumes and unique transaction IDs.
SELECT COUNT(*) AS transaction_rows,
       COUNT(DISTINCT transaction_id) AS unique_transaction_ids
FROM transactions;

-- 2. Transaction value and fees by transaction type (completed only).
SELECT transaction_type,
       COUNT(*) AS transaction_count,
       ROUND(SUM(gross_amount),2) AS gross_value,
       ROUND(SUM(fee_amount),2) AS total_fees
FROM transactions
WHERE transaction_status = 'Completed'
GROUP BY transaction_type
ORDER BY gross_value DESC;

-- 3. Monthly deposits and withdrawals.
SELECT DATE_FORMAT(transaction_date, '%Y-%m') AS transaction_month,
       SUM(CASE WHEN transaction_type='Deposit' THEN gross_amount ELSE 0 END) AS deposits,
       SUM(CASE WHEN transaction_type='Withdrawal' THEN gross_amount ELSE 0 END) AS withdrawals,
       SUM(CASE WHEN transaction_type='Deposit' THEN gross_amount
                WHEN transaction_type='Withdrawal' THEN -gross_amount
                ELSE 0 END) AS net_cash_flow
FROM transactions
WHERE transaction_status='Completed'
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY transaction_month;

-- 4. Highest-value clients.
SELECT c.clients_id, c.client_segment, c.region,
       COUNT(t.transaction_id) AS completed_transactions,
       ROUND(SUM(t.gross_amount), 2) AS total_transaction_value
FROM clients c
JOIN transactions t ON c.clients_id = t.client_id
WHERE t.transaction_status = 'Completed'
GROUP BY c.clients_id, c.client_segment, c.region
ORDER BY total_transaction_value DESC
LIMIT 15;

-- 5. Activity by asset class.
SELECT a.asset_class,
       COUNT(t.transaction_id) AS transaction_count,
       ROUND(SUM(t.gross_amount),2) AS total_value
FROM assets a
JOIN transactions t ON a.asset_id=t.asset_id
WHERE t.transaction_status='Completed'
GROUP BY a.asset_class
ORDER BY total_value DESC;

-- 6. Transaction status monitoring.
SELECT transaction_status,
       COUNT(*) AS transaction_count,
       ROUND(100*COUNT(*)/(SELECT COUNT(*) FROM transactions),2) AS percentage
FROM transactions
GROUP BY transaction_status;

-- 7. Failed transactions by month and type.
SELECT DATE_FORMAT(transaction_date,'%Y-%m') AS transaction_month,
       transaction_type,
       COUNT(*) AS failed_count,
       ROUND(SUM(gross_amount),2) AS failed_value
FROM transactions
WHERE transaction_status='Failed'
GROUP BY DATE_FORMAT(transaction_date,'%Y-%m'), transaction_type
ORDER BY transaction_month, failed_count DESC;

-- 8. Large completed transactions: review threshold is illustrative, not fraud proof.
SELECT transaction_id, client_id, transaction_date, transaction_type,
       gross_amount, transaction_status
FROM transactions
WHERE transaction_status='Completed'
  AND gross_amount >= 500000
ORDER BY gross_amount DESC;

-- 9. Client segment comparison.
SELECT c.client_segment,
       COUNT(DISTINCT c.clients_id) AS clients,
       COUNT(t.transaction_id) AS transactions,
       ROUND(AVG(t.gross_amount),2) AS average_transaction_amount,
       ROUND(SUM(t.gross_amount),2) AS total_transaction_value
FROM clients c
LEFT JOIN transactions t
  ON c.clients_id = t.client_id AND t.transaction_status = 'Completed'
GROUP BY c.client_segment
ORDER BY total_transaction_value DESC;

-- 10. Data-quality checks.
SELECT COUNT(*) AS missing_client_keys
FROM transactions t LEFT JOIN clients c ON t.client_id = c.clients_id
WHERE c.clients_id IS NULL;

SELECT COUNT(*) AS missing_asset_keys
FROM transactions t LEFT JOIN assets a ON t.asset_id = a.asset_id
WHERE a.asset_id IS NULL;

SELECT COUNT(*) AS invalid_amounts
FROM transactions
WHERE gross_amount < 0 OR fee_amount < 0 OR units < 0;


-- 11. Monthly completed transaction trend.
SELECT DATE_FORMAT(transaction_date,'%Y-%m') AS transaction_month,
       COUNT(*) AS completed_transactions,
       ROUND(SUM(gross_amount),2) AS completed_value
FROM transactions
WHERE transaction_status='Completed'
GROUP BY DATE_FORMAT(transaction_date,'%Y-%m')
ORDER BY transaction_month;
