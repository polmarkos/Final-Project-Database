-- DELETE RULES
--   CASCADE   : rows nga walay pulos kung kana ra sila
--               (role_permissions, managers, employee_rates, shifts, ingredient_cost_history,
--                recipe_items by menu item, system_settings, cost_forecasts,
--                transaction_details, cash/bank/card payment detail rows)
--   RESTRICT  : lookup data, users, ug bisan unsa nga gina reference sa
--               history/financial records kay dili pwede ma delete, accidentally or intentionally.
--   Not advised nga mag delete ug users, menu items, ingredients or completed transactions so soft delete nalang

CREATE TABLE roles (
    role_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_type  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE permissions (
    permission_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    permission_code  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE role_permissions (
    role_id        INT NOT NULL REFERENCES roles(role_id)             ON DELETE CASCADE,
    permission_id  INT NOT NULL REFERENCES permissions(permission_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE departments (
    department_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_name  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE branches (
    branch_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_name      VARCHAR(50)  NOT NULL UNIQUE,
    branch_location  VARCHAR(100) NOT NULL
);

CREATE TABLE users (
    user_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_num         VARCHAR(50)  NOT NULL UNIQUE,
    role_id        INT NOT NULL REFERENCES roles(role_id)             ON DELETE RESTRICT,
    branch_id      INT          REFERENCES branches(branch_id)        ON DELETE RESTRICT,
    department_id  INT          REFERENCES departments(department_id) ON DELETE RESTRICT,
    last_name      VARCHAR(50)  NOT NULL,
    middle_name    VARCHAR(50),
    first_name     VARCHAR(50)  NOT NULL,
    email          VARCHAR(100) NOT NULL UNIQUE,
    username       VARCHAR(20)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,  
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE managers (
    user_id          INT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    scope_branch_id  INT NOT NULL REFERENCES branches(branch_id) ON DELETE RESTRICT
);

-- Ang rate nga ma apply sa shift kay ang latest row with effective_date <= the shift date.
CREATE TABLE employee_rates (
    rate_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    hourly_rate     NUMERIC(10,2) NOT NULL,
    effective_date  DATE NOT NULL,
    CONSTRAINT uq_employee_rates_user_date UNIQUE (user_id, effective_date),
    CONSTRAINT ck_employee_rates_rate      CHECK (hourly_rate >= 0)
);

CREATE TABLE system_settings (
    setting_id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id                INT NOT NULL UNIQUE REFERENCES branches(branch_id) ON DELETE CASCADE,
    regular_hours_threshold  NUMERIC(4,2) NOT NULL DEFAULT 8.00,  
    overtime_multiplier      NUMERIC(3,2) NOT NULL DEFAULT 1.25,
    labor_cost_target_pct    NUMERIC(5,2) NOT NULL DEFAULT 25.00,
    food_cost_target_pct     NUMERIC(5,2) NOT NULL DEFAULT 30.00,
    CONSTRAINT ck_settings_threshold  CHECK (regular_hours_threshold > 0 AND regular_hours_threshold <= 24),
    CONSTRAINT ck_settings_multiplier CHECK (overtime_multiplier >= 1),
    CONSTRAINT ck_settings_labor_pct  CHECK (labor_cost_target_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_settings_food_pct   CHECK (food_cost_target_pct  BETWEEN 0 AND 100)
);

CREATE TABLE schedule_statuses (
    status_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_type  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE schedules (
    schedule_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id    INT NOT NULL REFERENCES branches(branch_id)               ON DELETE RESTRICT,
    start_date   DATE NOT NULL,
    end_date     DATE NOT NULL,
    status_id    INT NOT NULL REFERENCES schedule_statuses(status_id)      ON DELETE RESTRICT,
    created_by   INT NOT NULL REFERENCES users(user_id)                    ON DELETE RESTRICT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_schedules_dates CHECK (end_date >= start_date)
);

-- Kung mag delete ug sched ma apil ug delete ang shifts under ana nga sched.
-- (back-to-back shifts are allowed).
CREATE TABLE shifts (
    shift_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    schedule_id  INT NOT NULL REFERENCES schedules(schedule_id) ON DELETE CASCADE,
    user_id      INT NOT NULL REFERENCES users(user_id)         ON DELETE RESTRICT,
    shift_start  TIMESTAMPTZ NOT NULL,
    shift_end    TIMESTAMPTZ NOT NULL,
    created_by   INT NOT NULL REFERENCES users(user_id)         ON DELETE RESTRICT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_shifts_time CHECK (shift_end > shift_start)
);

CREATE TABLE measurement_units (
    unit_id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    unit_type          VARCHAR(50) NOT NULL UNIQUE,
    unit_abbreviation  VARCHAR(10) NOT NULL UNIQUE
);

-- ingredient_cost = CURRENT cost per unit. Kada change dapat mag insert ug row sa history.
CREATE TABLE ingredients (
    ingredient_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ingredient_name  VARCHAR(100) NOT NULL UNIQUE,
    unit_id          INT NOT NULL REFERENCES measurement_units(unit_id) ON DELETE RESTRICT,
    ingredient_cost  NUMERIC(10,2) NOT NULL,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_ingredients_cost CHECK (ingredient_cost >= 0)
);

CREATE TABLE ingredient_cost_history (
    history_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ingredient_id    INT NOT NULL REFERENCES ingredients(ingredient_id) ON DELETE CASCADE,
    ingredient_cost  NUMERIC(10,2) NOT NULL,
    effective_date   DATE NOT NULL,
    CONSTRAINT uq_cost_history_ingredient_date UNIQUE (ingredient_id, effective_date),
    CONSTRAINT ck_cost_history_cost CHECK (ingredient_cost >= 0)
);

CREATE TABLE menu_items (
    item_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_name         VARCHAR(100) NOT NULL UNIQUE,
    item_price        NUMERIC(10,2) NOT NULL,
    item_description  VARCHAR(255),
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_menu_items_price CHECK (item_price >= 0)
);

-- quantity_used is ALWAYS expressed in the ingredient's own unit
-- (0.150 means 0.150 kg if the ingredient is priced per kg).
-- Pag mag delete ug menu item mawala sad ang recipe item rows related ana nga menu item; ang ingredient nga gina gamit sa bisan unsa nga recipe di pwede idelete.
CREATE TABLE recipe_items (
    recipe_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id        INT NOT NULL REFERENCES menu_items(item_id)       ON DELETE CASCADE,
    ingredient_id  INT NOT NULL REFERENCES ingredients(ingredient_id) ON DELETE RESTRICT,
    quantity_used  NUMERIC(10,3) NOT NULL,
    CONSTRAINT uq_recipe_items_item_ingredient UNIQUE (item_id, ingredient_id),
    CONSTRAINT ck_recipe_items_qty             CHECK (quantity_used > 0)
);

CREATE TABLE payment_methods (
    method_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    method_type  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE order_types (
    order_type_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_type     VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE transaction_statuses (
    transaction_status_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_status_type  VARCHAR(50) NOT NULL UNIQUE
);

-- transaction_amount = net sales ("Total Sales" sa cost formulas)
-- total_food_cost    = SUM(unit_cost * unit_quantity), snapshotted pag macomplete ang order.
-- Dapat ang sales queries kay mag count rag transactions nga 'Completed' ang status.
-- Completed sales are voided/refunded (status change), never deleted.
CREATE TABLE transactions (
    transaction_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id              INT NOT NULL REFERENCES branches(branch_id)                          ON DELETE RESTRICT,
    processed_by           INT NOT NULL REFERENCES users(user_id)                               ON DELETE RESTRICT,
    method_id              INT NOT NULL REFERENCES payment_methods(method_id)                   ON DELETE RESTRICT,
    order_type_id          INT NOT NULL REFERENCES order_types(order_type_id)                   ON DELETE RESTRICT,
    transaction_status_id  INT NOT NULL REFERENCES transaction_statuses(transaction_status_id)  ON DELETE RESTRICT,
    transaction_date       TIMESTAMPTZ NOT NULL DEFAULT now(),
    transaction_amount     NUMERIC(10,2) NOT NULL,
    total_food_cost        NUMERIC(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_transactions_amount    CHECK (transaction_amount >= 0),
    CONSTRAINT ck_transactions_food_cost CHECK (total_food_cost >= 0)
);

-- unit_price and unit_cost are snapshots at the time of sale, para ang updated prices or ingredient-costs kay dili maka alter ug past transactions.
CREATE TABLE transaction_details (
    transaction_details_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id          INT NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    item_id                 INT NOT NULL REFERENCES menu_items(item_id)          ON DELETE RESTRICT,
    unit_price              NUMERIC(10,2) NOT NULL,
    unit_cost               NUMERIC(10,2) NOT NULL,
    unit_quantity           INT NOT NULL,
    subtotal                NUMERIC(10,2) NOT NULL,
    CONSTRAINT ck_txn_details_price    CHECK (unit_price >= 0),
    CONSTRAINT ck_txn_details_cost     CHECK (unit_cost >= 0),
    CONSTRAINT ck_txn_details_qty      CHECK (unit_quantity > 0),
    CONSTRAINT ck_txn_details_subtotal CHECK (subtotal = unit_price * unit_quantity)
);

-- dili gina cascade ang audit rows, ang transaction nga nay audit history kay di pwede idelete.
CREATE TABLE transaction_audit_history (
    history_id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id         INT NOT NULL REFERENCES transactions(transaction_id)                 ON DELETE RESTRICT,
    transaction_status_id  INT NOT NULL REFERENCES transaction_statuses(transaction_status_id)  ON DELETE RESTRICT,
    changed_by             INT NOT NULL REFERENCES users(user_id)                               ON DELETE RESTRICT,
    change_date            TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TABLE banks (
    bank_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bank_name  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE card_types (
    card_type_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    card_type     VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE card_brands (
    card_brand_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    card_brand_name  VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE bank_payment_statuses (
    status_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_type  VARCHAR(50) NOT NULL UNIQUE
);

-- dapat ang icreate ra nga table row kay mo match sa method id sa transac.
CREATE TABLE cash_payment_details (
    transaction_id  INT PRIMARY KEY REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    amount_paid     NUMERIC(10,2) NOT NULL,
    change_amount   NUMERIC(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_cash_amount_paid CHECK (amount_paid >= 0),
    CONSTRAINT ck_cash_change      CHECK (change_amount >= 0 AND change_amount <= amount_paid)
);

CREATE TABLE bank_transfer_payment_details (
    transaction_id       INT PRIMARY KEY REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    bank_id              INT NOT NULL REFERENCES banks(bank_id)                       ON DELETE RESTRICT,
    account_holder_name  VARCHAR(100) NOT NULL,
    reference_number     VARCHAR(50)  NOT NULL,
    transfer_date        TIMESTAMPTZ  NOT NULL,
    status_id            INT NOT NULL REFERENCES bank_payment_statuses(status_id)     ON DELETE RESTRICT,
    CONSTRAINT uq_bank_transfer_reference UNIQUE (bank_id, reference_number)
);

-- Dili istore ang full card number, expiry or CVV. Dapat last four digits + terminal approval code ra.
CREATE TABLE card_payment_details (
    transaction_id      INT PRIMARY KEY REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    card_type_id        INT NOT NULL REFERENCES card_types(card_type_id)         ON DELETE RESTRICT,
    card_brand_id       INT NOT NULL REFERENCES card_brands(card_brand_id)       ON DELETE RESTRICT,
    card_last_four      CHAR(4)      NOT NULL,
    approval_code       VARCHAR(20)  NOT NULL,
    terminal_reference  VARCHAR(50),
    CONSTRAINT ck_card_last_four CHECK (card_last_four ~ '^[0-9]{4}$')
);

-- Derived data: mawala kung mawala ang branch, gaka regenerate kada gabii (nightly scheduled job),
-- update kung naa na, insert kung wala pa sa (branch_id, forecast_date).
-- forecast_accuracy_pct = 100 - MAPE, forced to 0..100 by the job, so basically kung inaccurate by 18% ang forecast, MAPE is 18 tapos
-- 82 ang accuracy.
CREATE TABLE cost_forecasts (
    forecast_id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id                 INT NOT NULL REFERENCES branches(branch_id) ON DELETE CASCADE,
    forecast_date             DATE NOT NULL,
    predicted_sales           NUMERIC(12,2) NOT NULL,
    predicted_labor_cost_pct  NUMERIC(5,2)  NOT NULL,
    predicted_food_cost_pct   NUMERIC(5,2)  NOT NULL,
    forecast_accuracy_pct     NUMERIC(5,2),
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_cost_forecasts_branch_date UNIQUE (branch_id, forecast_date),
    CONSTRAINT ck_forecast_sales    CHECK (predicted_sales >= 0),
    CONSTRAINT ck_forecast_labor    CHECK (predicted_labor_cost_pct >= 0),
    CONSTRAINT ck_forecast_food     CHECK (predicted_food_cost_pct  >= 0),
    CONSTRAINT ck_forecast_accuracy CHECK (forecast_accuracy_pct IS NULL OR forecast_accuracy_pct BETWEEN 0 AND 100)
);

-- INDEXES 
CREATE INDEX idx_role_permissions_perm   ON role_permissions(permission_id);
CREATE INDEX idx_users_role              ON users(role_id);
CREATE INDEX idx_users_branch            ON users(branch_id);
CREATE INDEX idx_users_department        ON users(department_id);
CREATE INDEX idx_managers_scope_branch   ON managers(scope_branch_id);
CREATE INDEX idx_schedules_branch_dates  ON schedules(branch_id, start_date, end_date);
CREATE INDEX idx_schedules_created_by    ON schedules(created_by);
CREATE INDEX idx_shifts_schedule         ON shifts(schedule_id);
CREATE INDEX idx_shifts_user_start       ON shifts(user_id, shift_start);
CREATE INDEX idx_ingredients_unit        ON ingredients(unit_id);
CREATE INDEX idx_recipe_items_ingredient ON recipe_items(ingredient_id);
CREATE INDEX idx_transactions_branch_dt  ON transactions(branch_id, transaction_date);
CREATE INDEX idx_transactions_status     ON transactions(transaction_status_id);
CREATE INDEX idx_transactions_processed  ON transactions(processed_by);
CREATE INDEX idx_txn_details_txn         ON transaction_details(transaction_id);
CREATE INDEX idx_txn_details_item        ON transaction_details(item_id);
CREATE INDEX idx_txn_audit_txn           ON transaction_audit_history(transaction_id);

-- VIEWS: ang mga cost formulas
--    Food cost %  = Cost of Ingredients / Total Sales x 100
--    Labor cost % = Total Pay (Basic Pay + Overtime) / Total Sales x 100
--    Overtime = hours nga mo lapas sa regular_hours_threshold sa isa ka shift.
--    Ang shift nga walay rate row ang employee kay maset ang shift_pay = NULL (para dali ra pangitaon).
CREATE VIEW v_shift_pay AS
SELECT
    s.shift_id,
    sc.schedule_id,
    sc.branch_id,
    s.user_id,
    s.shift_start,
    h.hours,
    LEAST(h.hours, ss.regular_hours_threshold)             AS regular_hours,
    GREATEST(h.hours - ss.regular_hours_threshold, 0)      AS overtime_hours,
    r.hourly_rate,
    ROUND(
        LEAST(h.hours, ss.regular_hours_threshold) * r.hourly_rate
      + GREATEST(h.hours - ss.regular_hours_threshold, 0) * r.hourly_rate * ss.overtime_multiplier
    , 2)                                                   AS shift_pay
FROM shifts s
JOIN schedules sc       ON sc.schedule_id = s.schedule_id
JOIN system_settings ss ON ss.branch_id   = sc.branch_id
CROSS JOIN LATERAL (
    SELECT (EXTRACT(EPOCH FROM (s.shift_end - s.shift_start)) / 3600.0)::numeric AS hours
) h
LEFT JOIN LATERAL (
    SELECT er.hourly_rate
    FROM employee_rates er
    WHERE er.user_id = s.user_id
      AND er.effective_date <= (s.shift_start AT TIME ZONE 'Asia/Manila')::date
    ORDER BY er.effective_date DESC
    LIMIT 1
) r ON TRUE;

CREATE VIEW v_daily_branch_costs AS
WITH sales AS (
    SELECT t.branch_id,
           (t.transaction_date AT TIME ZONE 'Asia/Manila')::date AS day,
           SUM(t.transaction_amount) AS total_sales,
           SUM(t.total_food_cost)    AS food_cost
    FROM transactions t
    JOIN transaction_statuses ts ON ts.transaction_status_id = t.transaction_status_id
    WHERE ts.transaction_status_type = 'Completed'
    GROUP BY 1, 2
),
labor AS (
    SELECT branch_id,
           (shift_start AT TIME ZONE 'Asia/Manila')::date AS day,
           SUM(shift_pay) AS total_pay
    FROM v_shift_pay
    GROUP BY 1, 2
)
SELECT COALESCE(s.branch_id, l.branch_id)       AS branch_id,
       COALESCE(s.day, l.day)                   AS day,
       COALESCE(s.total_sales, 0)               AS total_sales,
       COALESCE(s.food_cost, 0)                 AS food_cost,
       COALESCE(l.total_pay, 0)                 AS total_pay,
       ROUND(100 * s.food_cost / NULLIF(s.total_sales, 0), 2) AS food_cost_pct,
       ROUND(100 * l.total_pay / NULLIF(s.total_sales, 0), 2) AS labor_cost_pct
FROM sales s
FULL JOIN labor l ON l.branch_id = s.branch_id AND l.day = s.day;

-- SEED DATA (lookups + permission matrix)
INSERT INTO roles (role_type) VALUES
    ('System Owner'), ('Management User'), ('Staff User'), ('Technical/Admin User');

INSERT INTO schedule_statuses       (status_type)             VALUES ('Draft'), ('Published'), ('Archived');
INSERT INTO payment_methods         (method_type)             VALUES ('Cash'), ('Bank Transfer'), ('Card');
INSERT INTO order_types             (order_type)              VALUES ('Dine-in'), ('Take-out');
INSERT INTO transaction_statuses    (transaction_status_type) VALUES ('Completed'), ('Refunded'), ('Voided');
INSERT INTO bank_payment_statuses   (status_type)             VALUES ('Confirmed'), ('Pending'), ('Failed');
INSERT INTO card_types              (card_type)               VALUES ('Debit'), ('Credit');
INSERT INTO card_brands             (card_brand_name)         VALUES ('Visa'), ('Mastercard'), ('JCB'), ('American Express'), ('UnionPay'), ('Other');
INSERT INTO measurement_units       (unit_type, unit_abbreviation) VALUES
    ('Kilogram', 'kg'), ('Gram', 'g'), ('Liter', 'L'), ('Milliliter', 'mL'), ('Piece', 'pc');

INSERT INTO permissions (permission_code) VALUES
    ('SCHEDULE_VIEW'), ('SCHEDULE_CREATE'), ('SCHEDULE_EDIT'), ('SCHEDULE_DELETE'),
    ('LABOR_COST_VIEW'), ('FOOD_COST_VIEW'), ('FORECAST_VIEW'),
    ('POS_PROCESS'), ('RECEIPT_VIEW'),
    ('USER_MANAGE'), ('ROLE_ASSIGN'), ('SETTINGS_CONFIGURE');

-- Makuha sa Sytem Owner tanan permission. New permissions nga ma add later on mag kinahanglan ug owner row as well.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r CROSS JOIN permissions p
WHERE r.role_type = 'System Owner';

-- Makuha sa staff ang SCHEDULE_VIEW cause makita nila ilang schedules
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM (VALUES
    ('Management User',      'SCHEDULE_VIEW'),
    ('Management User',      'SCHEDULE_CREATE'),
    ('Management User',      'SCHEDULE_EDIT'),
    ('Management User',      'SCHEDULE_DELETE'),
    ('Management User',      'LABOR_COST_VIEW'),
    ('Management User',      'FOOD_COST_VIEW'),
    ('Management User',      'FORECAST_VIEW'),
    ('Staff User',           'POS_PROCESS'),
    ('Staff User',           'RECEIPT_VIEW'),
    ('Staff User',           'SCHEDULE_VIEW'),
    ('Technical/Admin User', 'USER_MANAGE'),
    ('Technical/Admin User', 'ROLE_ASSIGN'),
    ('Technical/Admin User', 'SETTINGS_CONFIGURE')
) AS m(role_type, permission_code)
JOIN roles r       ON r.role_type       = m.role_type
JOIN permissions p ON p.permission_code = m.permission_code;