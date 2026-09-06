import mysql.connector
from mysql.connector import Error

DB_CONFIG = {
    "host": "127.0.0.1",
    "user": "root",
    "password": "YOUR_PASSWORD",
    "database": "finance_tracker",
}


def get_conn():
    return mysql.connector.connect(**DB_CONFIG)


def q1_show_transactions(conn):
    sql = """
    SELECT t.transaction_id, t.occurred_at, a.name AS account, c.name AS category,
           t.type, t.amount, t.description
    FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id
    JOIN categories c ON t.category_id = c.category_id
    WHERE t.user_id = %s
    ORDER BY t.occurred_at DESC;
    """
    user_id = int(input("User id (ex 1): "))
    cur = conn.cursor()
    cur.execute(sql, (user_id,))
    rows = cur.fetchall()
    print("\n--- Transactions ---")
    for r in rows:
        print(r)
    print()


def q2_spending_by_category(conn):
    sql = """
    SELECT c.name AS category, SUM(t.amount) AS spent
    FROM transactions t
    JOIN categories c ON t.category_id = c.category_id
    WHERE t.user_id = %s
      AND t.type = 'expense'
      AND DATE_FORMAT(t.occurred_at, '%Y-%m') = %s
    GROUP BY c.name
    ORDER BY spent DESC;
    """
    user_id = int(input("User id (ex 1): "))
    ym = input("Month (YYYY-MM) (ex 2026-02): ").strip()
    cur = conn.cursor()
    cur.execute(sql, (user_id, ym))
    rows = cur.fetchall()
    print("\n--- Spending per category ---")
    for r in rows:
        print(r)
    print()


def q3_account_balances(conn):
    sql = """
    SELECT a.name AS account,
           COALESCE(SUM(CASE WHEN t.type='income' THEN t.amount
                             ELSE -t.amount END), 0) AS balance
    FROM accounts a
    LEFT JOIN transactions t ON t.account_id = a.account_id
    WHERE a.user_id = %s
    GROUP BY a.account_id, a.name
    ORDER BY balance DESC;
    """
    user_id = int(input("User id (ex 1): "))
    cur = conn.cursor()
    cur.execute(sql, (user_id,))
    rows = cur.fetchall()
    print("\n--- Account balances ---")
    for r in rows:
        print(r)
    print()


def q4_budget_vs_spent(conn):
    sql = """
    SELECT b.`year_month`, c.name AS category, b.amount AS budget,
           COALESCE(SUM(t.amount),0) AS spent,
           (b.amount - COALESCE(SUM(t.amount),0)) AS remaining
    FROM budgets b
    JOIN categories c ON b.category_id = c.category_id
    LEFT JOIN transactions t
      ON t.user_id=b.user_id AND t.category_id=b.category_id
     AND t.type='expense'
     AND DATE_FORMAT(t.occurred_at,'%Y-%m')=b.`year_month`
    WHERE b.user_id=%s AND b.`year_month`=%s
    GROUP BY b.`year_month`, c.name, b.amount
    ORDER BY remaining ASC;
    """
    user_id = int(input("User id (ex 1): "))
    ym = input("Month (YYYY-MM) (ex 2026-02): ").strip()
    cur = conn.cursor()
    cur.execute(sql, (user_id, ym))
    rows = cur.fetchall()
    print("\n--- Budget vs spent ---")
    for r in rows:
        print(r)
    print()


def q5_show_alerts(conn):
    sql = """
    SELECT ba.alert_id, c.name AS category, ba.`year_month`,
           ba.spent_amount, ba.budget_amount, ba.created_at
    FROM budget_alerts ba
    JOIN categories c ON ba.category_id = c.category_id
    WHERE ba.user_id = %s
    ORDER BY ba.created_at DESC;
    """
    user_id = int(input("User id (ex 1): "))
    cur = conn.cursor()
    cur.execute(sql, (user_id,))
    rows = cur.fetchall()
    print("\n--- Alerts ---")
    for r in rows:
        print(r)
    print()


def add_transaction(conn):
    print("\nAdd transaction (uses stored procedure add_transaction)")
    user_id = int(input("user_id (ex 1): "))
    account_id = int(input("account_id (ex 1): "))
    category_id = int(input("category_id (ex 1): "))
    tx_type = input("type (income/expense): ").strip()
    amount = float(input("amount (ex 1200.00): "))
    occurred_at = input("occurred_at (YYYY-MM-DD HH:MM:SS): ").strip()
    desc = input("description: ").strip()
    cur = conn.cursor()
    cur.callproc("add_transaction", (user_id, account_id, category_id, tx_type, amount, occurred_at, desc))
    conn.commit()
    print("Transaction added.\n")


def main():
    try:
        conn = get_conn()
        print("Connected to MySQL \n")
        while True:
            print("=== Finance Tracker (CLI) ===")
            print("1) Add transaction")
            print("2) Show transactions (Q1)")
            print("3) Spending per category (Q2)")
            print("4) Account balances (Q3)")
            print("5) Budget vs spent (Q4)")
            print("6) Show alerts (Q5)")
            print("0) Exit")
            choice = input("Choose: ").strip()
            if choice == "1":
                add_transaction(conn)
            elif choice == "2":
                q1_show_transactions(conn)
            elif choice == "3":
                q2_spending_by_category(conn)
            elif choice == "4":
                q3_account_balances(conn)
            elif choice == "5":
                q4_budget_vs_spent(conn)
            elif choice == "6":
                q5_show_alerts(conn)
            elif choice == "0":
                break
            else:
                print("Try again.\n")
        conn.close()
        print("Bye!")
    except Error as e:
        print("MySQL error:", e)


if __name__ == "__main__":
    main()
