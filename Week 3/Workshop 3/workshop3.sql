CREATE EXTENSION IF NOT EXISTS pgcrypto;

--# DROP DATABASE IF EXISTS vet_db;
--# CREATE DATABASE vet_db;

-- THIS WILL DELETE EVERY SINGLE TABLE IN THE DATABASE. BE AWARE, NATTHAKIT.
--# DROP SCHEMA public CASCADE;
--# CREATE SCHEMA public;
--# GRANT ALL ON SCHEMA public TO public;

--$ \c vet_db

DROP TABLE IF EXISTS prescriptions       CASCADE;
DROP TABLE IF EXISTS visits              CASCADE;
DROP TABLE IF EXISTS staff_proficiencies CASCADE;
DROP TABLE IF EXISTS proficiencies       CASCADE;
DROP TABLE IF EXISTS inventory           CASCADE;
DROP TABLE IF EXISTS pets                CASCADE;
DROP TABLE IF EXISTS customer_addresses  CASCADE;
DROP TABLE IF EXISTS customer_tels       CASCADE;
DROP TABLE IF EXISTS staff               CASCADE;
DROP TABLE IF EXISTS customers           CASCADE;

-- ตารางนี้เก็บข้อมูลลูกค้าเฉพาะจำเป็น
CREATE TABLE IF NOT EXISTS customers (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),

    -- เก็บแค่ชื่อ สกุล ที่เหลือแยกออกไปตารางอื่น
    first_name  VARCHAR(25) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,

    CONSTRAINT pk_customers
        PRIMARY KEY (id)
);

-- แยกตารางเพราะว่าลูกค้า 1 ท่าน มีได้มากกว่า 1 เบอร์
CREATE TABLE IF NOT EXISTS customer_tels (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    customer_id UUID        NOT NULL,
    tel         VARCHAR(15) NOT NULL,

    CONSTRAINT pk_customer_tels
        PRIMARY KEY (id),
    CONSTRAINT fk_tels_customers
        FOREIGN KEY (customer_id)
            REFERENCES customers(id)
            ON DELETE CASCADE
);

-- แยกตารางเพราะว่าไม่อยากให้ตารางข้อมูลผู้ใช้มันอ้วนเกิน
-- ถ้าถามว่า: แล้วทำไมไม่เก็บเป็น plaintext ล่ะ? ไม่เอาครับ มันเคืองตา ใช้ก็ยาก แถมรกตารางอีก
-- วางแผนไว้ในอนาคตเผื่อเอาข้อมูลไปใช้ จะได้ใช้ได้ง่ายๆ ไม่มี technical debt
CREATE TABLE IF NOT EXISTS customer_addresses (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    customer_id UUID        NOT NULL,

    home_no     INTEGER     DEFAULT NULL,
    section     INTEGER     DEFAULT NULL,
    village     VARCHAR(25) DEFAULT NULL,
    road        VARCHAR(25) DEFAULT NULL,
    subdistrict VARCHAR(25) NOT NULL,
    district    VARCHAR(25) NOT NULL,
    province    VARCHAR(25) NOT NULL,
    zipcode     INTEGER     NOT NULL,

    CONSTRAINT pk_customer_addresses
        PRIMARY KEY (id),
    CONSTRAINT fk_addresses_customers
        FOREIGN KEY (customer_id)
            REFERENCES customers(id)
            ON DELETE CASCADE,

    -- บังคับว่าลูกค้า 1 ท่านจะใส่ที่อยู่แบบเดิมเป๊ะๆ ได้แค่ 1 ครั้งเท่านั้น
    UNIQUE (
        customer_id,
        home_no,
        section,
        village,
        road,
        subdistrict,
        district,
        province,
        zipcode
    )
);

-- ตารางเก็บข้อมูลสัตว์เลี้ยง
CREATE TABLE IF NOT EXISTS pets (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    customer_id UUID        NOT NULL,

    name        VARCHAR(20) NOT NULL,
    species     VARCHAR(25) NOT NULL,
    breed       VARCHAR(50) NOT NULL,
    date_of_birth   DATE    NOT NULL,
    -- ตามโจทย์บอกให้บอกอายุด้วย แต่ถ้าจะเก็บอายุเปล่าๆ มันดูแปลก เลยเก็บเป็นวันเดือนปีเกิดแทน :)

    CONSTRAINT pk_pets
        PRIMARY KEY (id),
    CONSTRAINT fk_pets_customers
        FOREIGN KEY (customer_id)
            REFERENCES customers(id)
            ON DELETE RESTRICT,

    CONSTRAINT uq_pets_customers
        UNIQUE (
            customer_id,
            name,
            species,
            breed,
            date_of_birth
        )
);

-- ตารางเก็บข้อมูลพนักงานใน vet
CREATE TABLE IF NOT EXISTS staff (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    first_name  VARCHAR(25) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,

    CONSTRAINT pk_staff
        PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS proficiencies (
    name        VARCHAR(20) NOT NULL,

    CONSTRAINT pk_proficiencies
        PRIMARY KEY (name),
    CONSTRAINT ck_proficiency_limited_to_presets
        CHECK (
            name IN (
                'general',
                'internal',
                'surgery',
                'dentistry',
                'dermatology',
                'ophthallmology',
                'cardiology',
                'neurology',
                'oncology',
                'orthopedics',
                'anesthesiology',
                'radiology',
                'nutrition',
                'behaviour'
            )
        )
);

CREATE TABLE IF NOT EXISTS staff_proficiencies (
    staff_id        UUID        NOT NULL,
    proficiency     VARCHAR(20) NOT NULL,

    CONSTRAINT pk_staff_proficiencies
        PRIMARY KEY (staff_id, proficiency),
    CONSTRAINT fk_proficiencies_staff
        FOREIGN KEY (staff_id)
            REFERENCES staff(id),
    CONSTRAINT fk_proficiencies_proficiency
        FOREIGN KEY (proficiency)
            REFERENCES proficiencies(name)
);

-- ตารางบันทึกข้อมูลการเข้ารักษาแต่ละครั้ง
CREATE TABLE IF NOT EXISTS visits (
    id          BIGINT      GENERATED ALWAYS AS IDENTITY,
    staff_id    UUID,
    pet_id      UUID        NOT NULL,

    symptoms    VARCHAR(500)    NOT NULL,
    date_time   TIMESTAMP   NOT NULL,

    CONSTRAINT pk_visits
        PRIMARY KEY (id),
    CONSTRAINT fk_visits_staff
        FOREIGN KEY (staff_id)
            REFERENCES staff(id)
            ON DELETE SET NULL,
    CONSTRAINT fk_visits_pets
        FOREIGN KEY (pet_id)
            REFERENCES pets(id)
            ON DELETE CASCADE
);

-- ตารางเก็บจำนวนสินค้าใน stock ว่าอะไรมีกี่อย่าง
CREATE TABLE IF NOT EXISTS inventory (
    id          BIGINT      GENERATED ALWAYS AS IDENTITY,
    name        VARCHAR(25) NOT NULL,
    category    VARCHAR(25) NOT NULL,

    -- ที่ต้องมี is_whole_package เพราะบางทียาบางตัวจ่ายเป็นเศษ เช่น
    -- metronidazole 1 package มี 50 เม็ด ไม่สามารถให้เจ้าของกลับไปหมดได้
    -- 1 package ที่มีอยู๋จึงแตกเป็น 0 package + 50 units จ่ายให้สัตว์ไป 10 เม็ด เหลือ 0 package + 40 units.
    -- whole | pkg | stk | con -> whole | pkg | stk |  con <- null เพราะเรานับยาเป็นเม็ดแทน ไม่ใช่กล่อง
    --  true |   1 |   1 |  50 -> false |   0 |  50 | null
    is_whole_package    BOOLEAN NOT NULL,
    stock_quantity      INT NOT NULL DEFAULT 0,
    content_quantity    INT DEFAULT NULL,
    usage_duration      INT NOT NULL DEFAULT 0,
    price       NUMERIC(10, 2)  NOT NULL,
    expiry_date TIMESTAMP   NOT NULL,

    CONSTRAINT pk_inventory_id
        PRIMARY KEY (id),
    CONSTRAINT ck_packaged_item_must_have_content_quantity
        CHECK (
            -- บังคับให้ต้องมีจำนวนยาต่อกล่องถ้าเป็นกล่อง และจำนวนยาต่อกล่องต้อง null ถ้านับเป็นเม็ด
            (is_whole_package = TRUE AND content_quantity IS NOT NULL)
            OR
            (is_whole_package = FALSE AND content_quantity IS NULL)
        ),
    CONSTRAINT ck_category_limited_to_presets
        CHECK (
            category IN (
                'painkiller',
                'antibiotic',
                'anti_inflammatory',
                'disinfectant',
                'antifungal',
                'antiparasitic',
                'antiviral',
                'antihistamine',
                'vaccine',
                'sedative',
                'laxative',
                'anesthetic',
                'supplement'
            )
        )
);

-- แยกตารางสั่งจ่ายยาออกมาจากตารางการมาหาหมอ เพราะมาหาหมอ 1 ครั้งหมอสั่งจ่ายยาได้หลายอย่าง
CREATE TABLE IF NOT EXISTS prescriptions (
    visit_id    BIGINT      NOT NULL,
    item_id     BIGINT      NOT NULL,

    quantity    INT         NOT NULL,

    CONSTRAINT pk_prescriptions
        PRIMARY KEY (visit_id, item_id),
    CONSTRAINT fk_prescriptions_visits
        FOREIGN KEY (visit_id)
            REFERENCES visits(id)
            ON DELETE CASCADE,
    CONSTRAINT fk_prescriptions_inventory
        FOREIGN KEY (item_id)
            REFERENCES inventory(id)
            ON DELETE RESTRICT
);