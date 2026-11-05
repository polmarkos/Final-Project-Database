-- =============================================================================
-- A. SYSTEM SETTINGS (DD031 - DD036)
-- =============================================================================
INSERT INTO system_settings (
    branch_id, 
    regular_hours_threshold, 
    overtime_multiplier, 
    labor_cost_target_pct, 
    food_cost_target_pct
)
SELECT 
    b.branch_id,
    8.00,
    1.25,
    25.00,
    30.00
FROM branches b
WHERE b.branch_name = 'Balay Kagayan';

-- =============================================================================
-- B. USERS & MANAGERS (DD001 - DD017)
-- =============================================================================
WITH role_lookup AS (
    SELECT role_id, role_type FROM roles
),
dept_lookup AS (
    SELECT department_id, department_name FROM departments
),
branch_lookup AS (
    SELECT branch_id FROM branches WHERE branch_name = 'Balay Kagayan' LIMIT 1
)
INSERT INTO users (
    id_num, role_id, branch_id, department_id,
    last_name, middle_name, first_name, email,
    username, password_hash, is_active, created_at
)
SELECT 
    d.id_num,
    r.role_id,
    CASE 
        WHEN d.role_type IN ('System Owner', 'Technical/Admin User') THEN NULL 
        ELSE b.branch_id 
    END AS branch_id,
    dp.department_id,
    d.last_name,
    d.middle_name,
    d.first_name,
    d.email,
    d.username,
    '$2a$10$w1e2r3t4y5u6i7o8p9a0sb0cdefghijklmno1234567890abcdef',
    true,
    NOW() - INTERVAL '60 days'
FROM (VALUES
    ('EMP-1001', 'System Owner',          NULL,            'Santos',    'M.', 'Eduardo', 'eduardo.santos@balaykagayan.ph',    'owner_eduardo'),
    ('EMP-1002', 'Management User',      'Back of House', 'Reyes',     'C.', 'Maria',   'maria.reyes@balaykagayan.ph',       'mgr_maria'),
    ('EMP-1003', 'Staff User',            'Back of House', 'Bautista',  'G.', 'Mark',    'mark.bautista@balaykagayan.ph',     'staff_mark'),
    ('EMP-1004', 'Staff User',            'Commissary',    'Villanueva','L.', 'Rica',    'rica.villanueva@balaykagayan.ph',   'staff_rica'),
    ('EMP-1005', 'Technical/Admin User', NULL,            'Tan',        'P.', 'Joshua',  'joshua.tan@balaykagayan.ph',        'admin_joshua')
) AS d(id_num, role_type, dept_name, last_name, middle_name, first_name, email, username)
JOIN role_lookup r       ON r.role_type = d.role_type
LEFT JOIN dept_lookup dp ON dp.department_name = d.dept_name
CROSS JOIN branch_lookup b;

-- Register Manager scope (DD016 - DD017)
INSERT INTO managers (user_id, scope_branch_id)
SELECT 
    u.user_id,
    (SELECT branch_id FROM branches WHERE branch_name = 'Balay Kagayan' LIMIT 1)
FROM users u
WHERE u.username = 'mgr_maria';

INSERT INTO employee_rates (user_id, hourly_rate, effective_date)
SELECT u.user_id, r.rate, (CURRENT_DATE - INTERVAL '60 days')::DATE
FROM (VALUES
    ('owner_eduardo', 250.00),
    ('mgr_maria',     150.00),
    ('staff_mark',     65.00),
    ('staff_rica',     65.00),
    ('admin_joshua',  120.00)
) AS r(username, rate)
JOIN users u ON u.username = r.username;

WITH units AS (
    SELECT unit_type, unit_id FROM measurement_units
)
INSERT INTO ingredients (ingredient_name, unit_id, ingredient_cost, is_active)
SELECT d.name, u.unit_id, d.cost, true
FROM (VALUES
    ('Whole Milk',                'Milliliter', 0.085),
    ('Espresso Beans',            'Gram',       0.900),
    ('Water / Filtered Ice',      'Milliliter', 0.005),
    ('Vanilla Syrup',             'Milliliter', 0.450),
    ('Caramel Syrup / Sauce',     'Milliliter', 0.500),
    ('Condensed Milk',            'Milliliter', 0.160),
    ('Evaporated Milk',           'Milliliter', 0.120),
    ('Ice Cream Base / Mix',      'Gram',       0.220),
    ('Whipped Cream',             'Gram',       0.350),
    ('Strawberry Puree',          'Milliliter', 0.400),
    ('Ube Halaya / Jam',          'Gram',       0.380),
    ('Ripe Mango Puree',          'Milliliter', 0.350),
    ('Coconut Milk (Gata)',       'Milliliter', 0.150),
    ('Beef Shank / Bulalo Cut',   'Gram',       0.420),
    ('Pork Belly (Liempo)',       'Gram',       0.340),
    ('Whole Chicken Cut-ups',     'Gram',       0.210),
    ('White Shrimp',              'Gram',       0.480),
    ('Fresh Tuna / Fish Cubes',   'Gram',       0.450),
    ('Fresh Calamansi',           'Gram',       0.100),
    ('Jasmine Rice (Raw)',        'Gram',       0.055),
    ('Cooking Oil',               'Milliliter', 0.080),
    ('Garlic & Onion Mix',        'Gram',       0.140),
    ('Soy Sauce & Vinegar Blend', 'Milliliter', 0.060),
    ('Bulalo Soup Veggies',       'Gram',       0.120),
    ('Saba Banana',               'Piece',      5.000),
    ('Lumpia Wrapper',            'Piece',      1.500),
    ('Brown Sugar',               'Gram',       0.075)
) AS d(name, unit_type, cost)
JOIN units u ON u.unit_type = d.unit_type;

INSERT INTO ingredient_cost_history (ingredient_id, ingredient_cost, effective_date)
SELECT i.ingredient_id, i.ingredient_cost, (CURRENT_DATE - INTERVAL '60 days')::DATE
FROM ingredients i;

INSERT INTO menu_items (item_name, item_price, item_description, is_active)
VALUES
    ('Americano (Hot 8oz)',                 125.00, 'Double shot espresso diluted with hot water', true),
    ('Americano (Cold 12oz)',               145.00, 'Double shot espresso served over chilled water and ice', true),
    ('Café Latte (Hot 8oz)',                145.00, 'Rich espresso with steamed whole milk', true),
    ('Café Latte (Cold 12oz)',              165.00, 'Rich espresso poured over fresh cold milk and ice', true),
    ('Spanish Latte (Hot 8oz)',             165.00, 'Espresso sweetened with condensed and steamed fresh milk', true),
    ('Spanish Latte (Cold 12oz)',           185.00, 'Sweetened condensed milk, espresso, and cold milk over ice', true),
    ('Mangga''t Suman Pinoy Latte',         195.00, 'Signature native latte with mango puree and sticky rice base', true),
    ('Ube - Puto Bumbong Latte',            255.00, 'Dessert latte infused with native purple yam and coconut notes', true),
    ('Strawberry Milkshake',                185.00, 'Blended strawberry ice cream shake topped with whipped cream', true),
    ('Buko Pandan Shake',                   185.00, 'Creamy young coconut and aromatic pandan blended shake', true),
    ('Ube Flan Shake',                      185.00, 'Rich ube shake layered with creamy leche flan', true),
    ('Kinilaw (Gamay)',                     215.00, 'Fresh raw fish ceviche cured in native vinegar and calamansi', true),
    ('Kinilaw (Dako)',                      395.00, 'Platter-sized native vinegar cured fresh fish ceviche', true),
    ('Beef Bulalo (Gamay)',                 495.00, 'Slow-simmered beef marrow and shank soup with fresh vegetables', true),
    ('Beef Bulalo (Dako)',                  795.00, 'Family-sized simmered beef shank and bone marrow rich broth', true),
    ('Pandan Chicken (Gamay)',              265.00, 'Marinated savory chicken thighs wrapped in fragrant pandan leaf', true),
    ('Chicken Adobo (Gamay)',               215.00, 'Classic Filipino stewed chicken braised in soy sauce, vinegar, and garlic', true),
    ('Lechon Kawali (Gamay)',               295.00, 'Deep-fried crispy pork belly slab served with spiced liver sauce', true),
    ('Crispy Pata (Gamay)',                 795.00, 'Whole deep-fried pork knuckle with crispy skin and tender meat', true),
    ('Pork BBQ w/ Rice',                    215.00, 'Skewered grilled pork barbecue served with steamed rice', true),
    ('Rice Cup',                             65.00, 'Single serving of steamed plain jasmine rice', true),
    ('Java/Garlic Rice Cup',                 75.00, 'Single cup of fragrant toasted garlic rice', true),
    ('Turon Ala Mode (1pc)',                195.00, 'Crispy fried banana-langka roll topped with vanilla ice cream', true),
    ('Leche Flan',                          165.00, 'Traditional steamed caramel custard dessert', true);

INSERT INTO recipe_items (item_id, ingredient_id, quantity_used)
SELECT m.item_id, i.ingredient_id, r.qty
FROM (VALUES
    ('Americano (Hot 8oz)',       'Espresso Beans',            18.000),
    ('Americano (Hot 8oz)',       'Water / Filtered Ice',      180.000),
    ('Café Latte (Hot 8oz)',      'Espresso Beans',            18.000),
    ('Café Latte (Hot 8oz)',      'Whole Milk',                180.000),
    ('Spanish Latte (Hot 8oz)',   'Espresso Beans',            18.000),
    ('Spanish Latte (Hot 8oz)',   'Whole Milk',                140.000),
    ('Spanish Latte (Hot 8oz)',   'Condensed Milk',            40.000),
    ('Ube - Puto Bumbong Latte',  'Espresso Beans',            18.000),
    ('Ube - Puto Bumbong Latte',  'Whole Milk',                140.000),
    ('Ube - Puto Bumbong Latte',  'Ube Halaya / Jam',          50.000),
    ('Ube - Puto Bumbong Latte',  'Coconut Milk (Gata)',       50.000),
    ('Strawberry Milkshake',      'Ice Cream Base / Mix',      120.000),
    ('Strawberry Milkshake',      'Whole Milk',                100.000),
    ('Strawberry Milkshake',      'Strawberry Puree',          45.000),
    ('Strawberry Milkshake',      'Whipped Cream',             25.000),
    ('Kinilaw (Gamay)',           'Fresh Tuna / Fish Cubes',   120.000),
    ('Kinilaw (Gamay)',           'Fresh Calamansi',           30.000),
    ('Kinilaw (Gamay)',           'Soy Sauce & Vinegar Blend', 35.000),
    ('Kinilaw (Gamay)',           'Garlic & Onion Mix',        20.000),
    ('Beef Bulalo (Gamay)',       'Beef Shank / Bulalo Cut',   300.000),
    ('Beef Bulalo (Gamay)',       'Bulalo Soup Veggies',       150.000),
    ('Beef Bulalo (Gamay)',       'Garlic & Onion Mix',        15.000),
    ('Chicken Adobo (Gamay)',     'Whole Chicken Cut-ups',     220.000),
    ('Chicken Adobo (Gamay)',     'Soy Sauce & Vinegar Blend', 40.000),
    ('Chicken Adobo (Gamay)',     'Garlic & Onion Mix',        20.000),
    ('Chicken Adobo (Gamay)',     'Cooking Oil',               15.000),
    ('Lechon Kawali (Gamay)',     'Pork Belly (Liempo)',       240.000),
    ('Lechon Kawali (Gamay)',     'Cooking Oil',               40.000),
    ('Lechon Kawali (Gamay)',     'Garlic & Onion Mix',        10.000),
    ('Rice Cup',                  'Jasmine Rice (Raw)',        80.000),
    ('Turon Ala Mode (1pc)',      'Saba Banana',               1.000),
    ('Turon Ala Mode (1pc)',      'Lumpia Wrapper',            1.000),
    ('Turon Ala Mode (1pc)',      'Brown Sugar',               20.000),
    ('Turon Ala Mode (1pc)',      'Ice Cream Base / Mix',      60.000),
    ('Turon Ala Mode (1pc)',      'Cooking Oil',               20.000)
) AS r(menu_name, ing_name, qty)
JOIN menu_items m  ON m.item_name = r.menu_name
JOIN ingredients i ON i.ingredient_name = r.ing_name;

DO $$
DECLARE
    v_branch_id INT;
    v_mgr_id INT;
    v_status_published INT;
    v_sched_1 INT;
    v_sched_2 INT;
    v_sched_3 INT;
    v_sched_4 INT;
    v_mark_id INT;
    v_rica_id INT;
    v_base_monday DATE;
    v_week INT;
    v_day INT;
    v_shift_date DATE;
    v_current_sched_id INT;
BEGIN
    SELECT branch_id INTO v_branch_id FROM branches WHERE branch_name = 'Balay Kagayan' LIMIT 1;
    SELECT user_id INTO v_mgr_id FROM users WHERE username = 'mgr_maria' LIMIT 1;
    SELECT status_id INTO v_status_published FROM schedule_statuses WHERE status_type = 'Published' LIMIT 1;
    SELECT user_id INTO v_mark_id FROM users WHERE username = 'staff_mark' LIMIT 1;
    SELECT user_id INTO v_rica_id FROM users WHERE username = 'staff_rica' LIMIT 1;

    v_base_monday := DATE_TRUNC('week', CURRENT_DATE - INTERVAL '28 days')::DATE;

    INSERT INTO schedules (branch_id, start_date, end_date, status_id, created_by, created_at)
    VALUES (v_branch_id, v_base_monday, v_base_monday + 6, v_status_published, v_mgr_id, NOW() - INTERVAL '30 days')
    RETURNING schedule_id INTO v_sched_1;

    INSERT INTO schedules (branch_id, start_date, end_date, status_id, created_by, created_at)
    VALUES (v_branch_id, v_base_monday + 7, v_base_monday + 13, v_status_published, v_mgr_id, NOW() - INTERVAL '23 days')
    RETURNING schedule_id INTO v_sched_2;

    INSERT INTO schedules (branch_id, start_date, end_date, status_id, created_by, created_at)
    VALUES (v_branch_id, v_base_monday + 14, v_base_monday + 20, v_status_published, v_mgr_id, NOW() - INTERVAL '16 days')
    RETURNING schedule_id INTO v_sched_3;

    INSERT INTO schedules (branch_id, start_date, end_date, status_id, created_by, created_at)
    VALUES (v_branch_id, v_base_monday + 21, v_base_monday + 27, v_status_published, v_mgr_id, NOW() - INTERVAL '9 days')
    RETURNING schedule_id INTO v_sched_4;

    FOR v_week IN 0..3 LOOP
        v_current_sched_id := CASE 
            WHEN v_week = 0 THEN v_sched_1
            WHEN v_week = 1 THEN v_sched_2
            WHEN v_week = 2 THEN v_sched_3
            ELSE v_sched_4
        END;

        FOR v_day IN 0..6 LOOP
            v_shift_date := v_base_monday + (v_week * 7) + v_day;

            IF v_day BETWEEN 0 AND 4 THEN
                INSERT INTO shifts (schedule_id, user_id, shift_start, shift_end, created_by, created_at)
                VALUES (
                    v_current_sched_id, v_mgr_id,
                    (v_shift_date + TIME '08:30:00')::TIMESTAMPTZ,
                    (v_shift_date + TIME '17:30:00')::TIMESTAMPTZ,
                    v_mgr_id, NOW() - INTERVAL '30 days'
                );
            END IF;

            IF v_day <> 1 THEN
                INSERT INTO shifts (schedule_id, user_id, shift_start, shift_end, created_by, created_at)
                VALUES (
                    v_current_sched_id, v_mark_id,
                    (v_shift_date + TIME '08:00:00')::TIMESTAMPTZ,
                    (v_shift_date + TIME '17:00:00')::TIMESTAMPTZ,
                    v_mgr_id, NOW() - INTERVAL '30 days'
                );
            END IF;

            IF v_day <> 2 THEN
                INSERT INTO shifts (schedule_id, user_id, shift_start, shift_end, created_by, created_at)
                VALUES (
                    v_current_sched_id, v_rica_id,
                    (v_shift_date + TIME '13:00:00')::TIMESTAMPTZ,
                    (v_shift_date + TIME '22:00:00')::TIMESTAMPTZ,
                    v_mgr_id, NOW() - INTERVAL '30 days'
                );
            END IF;

            IF v_day IN (5, 6) THEN
                INSERT INTO shifts (schedule_id, user_id, shift_start, shift_end, created_by, created_at)
                VALUES (
                    v_current_sched_id, v_mark_id,
                    (v_shift_date + TIME '18:00:00')::TIMESTAMPTZ,
                    (v_shift_date + TIME '22:00:00')::TIMESTAMPTZ,
                    v_mgr_id, NOW() - INTERVAL '30 days'
                );
                INSERT INTO shifts (schedule_id, user_id, shift_start, shift_end, created_by, created_at)
                VALUES (
                    v_current_sched_id, v_rica_id,
                    (v_shift_date + TIME '09:00:00')::TIMESTAMPTZ,
                    (v_shift_date + TIME '13:00:00')::TIMESTAMPTZ,
                    v_mgr_id, NOW() - INTERVAL '30 days'
                );
            END IF;
        END LOOP;
    END LOOP;
END $$;

DO $$
DECLARE
    v_trans_id INT;
    v_branch_id INT;
    v_cashier_id INT;
    v_cash_method_id INT;
    v_card_method_id INT;
    v_selected_method_id INT;
    v_dine_in_id INT;
    v_take_out_id INT;
    v_selected_order_type_id INT;
    v_status_id INT;
    v_debit_type_id INT;
    v_credit_type_id INT;
    v_selected_card_type_id INT;
    v_visa_brand_id INT;
    v_mc_brand_id INT;
    v_selected_brand_id INT;
    v_item RECORD;
    v_line_qty INT;
    v_total_sales NUMERIC(10,2);
    v_total_cost NUMERIC(10,2);
    v_random_days INT;
    v_random_seconds INT;
    v_trans_time TIMESTAMPTZ;
BEGIN
    SELECT branch_id INTO v_branch_id FROM branches WHERE branch_name = 'Balay Kagayan' LIMIT 1;
    SELECT user_id INTO v_cashier_id FROM users WHERE username = 'staff_mark' LIMIT 1;
    SELECT method_id INTO v_cash_method_id FROM payment_methods WHERE method_type = 'Cash' LIMIT 1;
    SELECT method_id INTO v_card_method_id FROM payment_methods WHERE method_type = 'Card' LIMIT 1;
    SELECT order_type_id INTO v_dine_in_id FROM order_types WHERE order_type = 'Dine-in' LIMIT 1;
    SELECT order_type_id INTO v_take_out_id FROM order_types WHERE order_type = 'Take-out' LIMIT 1;
    SELECT transaction_status_id INTO v_status_id FROM transaction_statuses WHERE transaction_status_type = 'Completed' LIMIT 1;
    SELECT card_type_id INTO v_debit_type_id FROM card_types WHERE card_type = 'Debit' LIMIT 1;
    SELECT card_type_id INTO v_credit_type_id FROM card_types WHERE card_type = 'Credit' LIMIT 1;
    SELECT card_brand_id INTO v_visa_brand_id FROM card_brands WHERE card_brand_name = 'Visa' LIMIT 1;
    SELECT card_brand_id INTO v_mc_brand_id FROM card_brands WHERE card_brand_name = 'Mastercard' LIMIT 1;

    CREATE TEMP TABLE tmp_item_cost_cache ON COMMIT DROP AS
    SELECT 
        m.item_id,
        m.item_price,
        ROUND(COALESCE(SUM(r.quantity_used * i.ingredient_cost), m.item_price * 0.25), 2) AS unit_cost
    FROM menu_items m
    LEFT JOIN recipe_items r ON m.item_id = r.item_id
    LEFT JOIN ingredients i ON r.ingredient_id = i.ingredient_id
    GROUP BY m.item_id, m.item_price;

    FOR i IN 1..500 LOOP
        v_total_sales := 0.00;
        v_total_cost  := 0.00;

        v_random_days := FLOOR(RANDOM() * 28)::INT;
        v_random_seconds := FLOOR(RANDOM() * (13 * 3600))::INT;
        v_trans_time := (CURRENT_DATE - v_random_days) + TIME '09:00:00' + (v_random_seconds || ' seconds')::INTERVAL;

        IF RANDOM() < 0.65 THEN
            v_selected_method_id := v_cash_method_id;
        ELSE
            v_selected_method_id := v_card_method_id;
        END IF;

        IF RANDOM() < 0.75 THEN
            v_selected_order_type_id := v_dine_in_id;
        ELSE
            v_selected_order_type_id := v_take_out_id;
        END IF;

        INSERT INTO transactions (
            branch_id,
            processed_by,
            method_id,
            order_type_id,
            transaction_status_id,
            transaction_date,
            transaction_amount,
            total_food_cost
        ) VALUES (
            v_branch_id,
            v_cashier_id,
            v_selected_method_id,
            v_selected_order_type_id,
            v_status_id,
            v_trans_time,
            0.00,
            0.00
        ) RETURNING transaction_id INTO v_trans_id;

        FOR v_item IN (
            SELECT item_id, item_price, unit_cost 
            FROM tmp_item_cost_cache 
            ORDER BY RANDOM() 
            LIMIT (FLOOR(RANDOM() * 4) + 1)::INT
        ) LOOP
            v_line_qty := (FLOOR(RANDOM() * 2) + 1)::INT;

            INSERT INTO transaction_details (
                transaction_id,
                item_id,
                unit_price,
                unit_cost,
                unit_quantity,
                subtotal
            ) VALUES (
                v_trans_id,
                v_item.item_id,
                v_item.item_price,
                v_item.unit_cost,
                v_line_qty,
                ROUND(v_item.item_price * v_line_qty, 2)
            );

            v_total_sales := v_total_sales + (v_item.item_price * v_line_qty);
            v_total_cost  := v_total_cost + (v_item.unit_cost * v_line_qty);
        END LOOP;

        UPDATE transactions 
        SET transaction_amount = v_total_sales,
            total_food_cost = v_total_cost
        WHERE transaction_id = v_trans_id;

        IF v_selected_method_id = v_cash_method_id THEN
            INSERT INTO cash_payment_details (
                transaction_id,
                amount_paid,
                change_amount
            ) VALUES (
                v_trans_id,
                CEIL(v_total_sales / 100.0) * 100,
                (CEIL(v_total_sales / 100.0) * 100) - v_total_sales
            );
        ELSE
            v_selected_card_type_id := CASE WHEN RANDOM() < 0.5 THEN v_debit_type_id ELSE v_credit_type_id END;
            v_selected_brand_id     := CASE WHEN RANDOM() < 0.6 THEN v_visa_brand_id ELSE v_mc_brand_id END;

            INSERT INTO card_payment_details (
                transaction_id,
                card_type_id,
                card_brand_id,
                card_last_four,
                approval_code,
                terminal_reference
            ) VALUES (
                v_trans_id,
                v_selected_card_type_id,
                v_selected_brand_id,
                LPAD((FLOOR(RANDOM() * 9000) + 1000)::TEXT, 4, '0'),
                LPAD((FLOOR(RANDOM() * 900000) + 100000)::TEXT, 6, '0'),
                'BK-POS-' || LPAD((FLOOR(RANDOM() * 9000) + 1000)::TEXT, 4, '0')
            );
        END IF;

    END LOOP;
END $$;