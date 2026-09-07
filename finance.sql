CREATE DATABASE IF NOT EXISTS finance_tracker
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE finance_tracker;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS budget_alerts;
DROP TABLE IF EXISTS budgets;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE accounts (
  account_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_accounts_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_user_account (user_id, name)
) ENGINE=InnoDB;

CREATE TABLE categories (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE transactions (
  transaction_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  account_id INT NOT NULL,
  category_id INT NOT NULL,
  type ENUM('income','expense') NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  occurred_at DATETIME NOT NULL,
  description VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_tx_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,

  CONSTRAINT fk_tx_account
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
    ON DELETE RESTRICT,

  CONSTRAINT fk_tx_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON DELETE RESTRICT,

  INDEX idx_tx_user_date (user_id, occurred_at)
) ENGINE=InnoDB;

CREATE TABLE budgets (
  budget_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  category_id INT NOT NULL,
  `year_month` CHAR(7) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,

  CONSTRAINT fk_budget_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,

  CONSTRAINT fk_budget_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON DELETE RESTRICT,

  UNIQUE KEY uq_budget (user_id, category_id, `year_month`)
) ENGINE=InnoDB;

CREATE TABLE budget_alerts (
  alert_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  category_id INT NOT NULL,
  `year_month` CHAR(7) NOT NULL,
  spent_amount DECIMAL(10,2) NOT NULL,
  budget_amount DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_alert_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,

  CONSTRAINT fk_alert_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON DELETE RESTRICT
) ENGINE=InnoDB;

INSERT INTO users (name, email) VALUES ('Raja', 'raja@example.com');

INSERT INTO accounts (user_id, name) VALUES
(1, 'Debit Card'),
(1, 'Cash');

INSERT INTO categories (name) VALUES
('Food'),
('Rent'),
('Transport'),
('Subscriptions'),
('Entertainment'),
('Salary');

INSERT INTO budgets (user_id, category_id, `year_month`, amount)
VALUES (
  1,
  (SELECT category_id FROM categories WHERE name='Food' LIMIT 1),
  '2026-02',
  2000.00
);

DROP PROCEDURE IF EXISTS add_transaction;
DELIMITER $$

CREATE PROCEDURE add_transaction(
  IN p_user_id INT,
  IN p_account_id INT,
  IN p_category_id INT,
  IN p_type VARCHAR(10),
  IN p_amount DECIMAL(10,2),
  IN p_occurred_at DATETIME,
  IN p_description VARCHAR(255)
)
BEGIN
  IF p_type NOT IN ('income','expense') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'type must be income or expense';
  END IF;

  INSERT INTO transactions(user_id, account_id, category_id, type, amount, occurred_at, description)
  VALUES (p_user_id, p_account_id, p_category_id, p_type, p_amount, p_occurred_at, p_description);
END $$

DELIMITER ;

DROP TRIGGER IF EXISTS trg_budget_alert;
DELIMITER $$

CREATE TRIGGER trg_budget_alert
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
  DECLARE v_month CHAR(7);
  DECLARE v_budget DECIMAL(10,2);
  DECLARE v_spent DECIMAL(10,2);

  SET v_month = DATE_FORMAT(NEW.occurred_at, '%Y-%m');

  IF NEW.type = 'expense' THEN
    SELECT amount INTO v_budget
    FROM budgets
    WHERE user_id = NEW.user_id
      AND category_id = NEW.category_id
      AND `year_month` = v_month
    LIMIT 1;

    IF v_budget IS NOT NULL THEN
      SELECT COALESCE(SUM(amount),0) INTO v_spent
      FROM transactions
      WHERE user_id = NEW.user_id
        AND category_id = NEW.category_id
        AND type='expense'
        AND DATE_FORMAT(occurred_at,'%Y-%m') = v_month;

      IF v_spent > v_budget THEN
        INSERT INTO budget_alerts(user_id, category_id, `year_month`, spent_amount, budget_amount)
        VALUES (NEW.user_id, NEW.category_id, v_month, v_spent, v_budget);
      END IF;
    END IF;
  END IF;
END $$

DELIMITER ;

CALL add_transaction(
  1,
  (SELECT account_id FROM accounts WHERE user_id=1 AND name='Debit Card' LIMIT 1),
  (SELECT category_id FROM categories WHERE name='Food' LIMIT 1),
  'expense',
  1200.00,
  '2026-02-05 18:30:00',
  'Groceries'
);

CALL add_transaction(
  1,
  (SELECT account_id FROM accounts WHERE user_id=1 AND name='Debit Card' LIMIT 1),
  (SELECT category_id FROM categories WHERE name='Food' LIMIT 1),
  'expense',
  900.00,
  '2026-02-10 20:00:00',
  'Restaurant'
);

CALL add_transaction(
  1,
  (SELECT account_id FROM accounts WHERE user_id=1 AND name='Debit Card' LIMIT 1),
(SELECT category_id FROM categories WHERE name='Salary' LIMIT 1),
  'income',
  15000.00,
  '2026-02-01 09:00:00',
  'Salary'
);


SELECT t.transaction_id, t.occurred_at, a.name AS account, c.name AS category,
       t.type, t.amount, t.description
FROM transactions t
JOIN accounts a  ON t.account_id = a.account_id
JOIN categories c ON t.category_id = c.category_id
WHERE t.user_id = 1
ORDER BY t.occurred_at DESC;

SELECT c.name AS category, SUM(t.amount) AS spent
FROM transactions t
JOIN categories c ON t.category_id = c.category_id
WHERE t.user_id = 1
  AND t.type = 'expense'
  AND DATE_FORMAT(t.occurred_at, '%Y-%m') = '2026-02'
GROUP BY c.name
ORDER BY spent DESC;

SELECT DATE_FORMAT(occurred_at, '%Y-%m') AS month,
       SUM(CASE WHEN type='income' THEN amount ELSE 0 END) AS income,
       SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) AS expense,
       SUM(CASE WHEN type='income' THEN amount ELSE -amount END) AS net
FROM transactions
WHERE user_id = 1
GROUP BY month
ORDER BY month;

SELECT a.name AS account,
       COALESCE(SUM(CASE WHEN t.type='income' THEN t.amount ELSE -t.amount END),0) AS balance
FROM accounts a
LEFT JOIN transactions t ON t.account_id = a.account_id
WHERE a.user_id = 1
GROUP BY a.account_id, a.name
ORDER BY balance DESC;

SELECT b.`year_month`, c.name AS category, b.amount AS budget,
       COALESCE(SUM(t.amount),0) AS spent,
       (b.amount - COALESCE(SUM(t.amount),0)) AS remaining
FROM budgets b
JOIN categories c ON b.category_id = c.category_id
LEFT JOIN transactions t
  ON t.user_id=b.user_id AND t.category_id=b.category_id
 AND t.type='expense'
 AND DATE_FORMAT(t.occurred_at,'%Y-%m')=b.`year_month`
WHERE b.user_id=1 AND b.`year_month`='2026-02'
GROUP BY b.`year_month`, c.name, b.amount
ORDER BY remaining ASC;

SELECT *
FROM budget_alerts
WHERE user_id = 1
ORDER BY created_at DESC;

SHOW TABLES;
