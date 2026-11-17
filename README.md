# Personal Finance Tracker

Database project (DV1703) by Raja Aldouni. A Python console application on top of a MySQL database that records income and expenses, shows reports, and creates budget alerts automatically with a trigger.

## Files

- `finance.sql` – database dump: schema, demonstration data, stored procedure `add_transaction` and trigger `trg_budget_alert`
- `app.py` – Python console application (mysql-connector-python, no ORM)
- `requirements.txt` – Python dependency

## Requirements

- Python 3.10 or later
- MySQL 8.0 or later
- mysql-connector-python

## Setup

```bash
python3 -m pip install -r requirements.txt
mysql -u root -p < finance.sql
```

Importing `finance.sql` recreates the `finance_tracker` database tables, so use a test environment.

Open `app.py` and replace `YOUR_PASSWORD` in `DB_CONFIG` with your MySQL password. Then run:

```bash
python3 app.py
```

## Menu

1. Add transaction (calls the stored procedure `add_transaction`)
2. Show transactions (Q1)
3. Spending per category for a month (Q2)
4. Account balances (Q3)
5. Budget vs spent for a month (Q4)
6. Show budget alerts (Q5)
0. Exit

## Demonstration

Use user id `1` and month `2026-02`:

- Q2: Food spending 2100.00
- Q4: Food budget 2000.00, spent 2100.00, remaining -100.00
- Q5: one alert created by the trigger (spent 2100.00 against budget 2000.00)

Adding another Food expense in February 2026 through menu option 1 creates a new alert automatically.
