CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- DROP DATABASE IF EXISTS vet_db;
-- CREATE DATABASE vet_db;

-- \c vet_db

CREATE TABLE IF NOT EXISTS customers (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    first_name  VARCHAR(25) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,

    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS customer_tels (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    customer_id UUID        NOT NULL,
    tel         VARCHAR(15) NOT NULL,

    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

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

    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
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

CREATE TABLE IF NOT EXISTS pets (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    customer_id UUID        NOT NULL,

    name        VARCHAR(20) NOT NULL,
    species     VARCHAR(25) NOT NULL,
    breed       VARCHAR(50) NOT NULL,
    date_of_birth   DATE    NOT NULL,

    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    UNIQUE (
        customer_id,
        name,
        species,
        breed,
        date_of_birth
    )
);

CREATE TABLE IF NOT EXISTS staff (
    id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    first_name  VARCHAR(25) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    proficiency VARCHAR(20) NOT NULL,

    PRIMARY KEY (id),
    CONSTRAINT proficiency_limited_to_presets
        CHECK (
            proficiency IN (
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

CREATE TABLE IF NOT EXISTS visits (
    id          BIGINT      GENERATED ALWAYS AS IDENTITY,
    staff_id    UUID        NOT NULL,
    pet_id      UUID        NOT NULL,

    symptoms    VARCHAR(500)    NOT NULL,
    date_time   TIMESTAMP   NOT NULL,

    PRIMARY KEY (id),
    FOREIGN KEY (staff_id) REFERENCES staff(id),
    FOREIGN KEY (pet_id)   REFERENCES pets(id)
);

CREATE TABLE IF NOT EXISTS inventory (
    id          BIGINT      GENERATED ALWAYS AS IDENTITY,
    name        VARCHAR(25) NOT NULL,
    category    VARCHAR(25) NOT NULL,
    is_whole_package    BOOLEAN NOT NULL,
    stock_quantity      INT NOT NULL DEFAULT 0,
    content_quantity    INT DEFAULT NULL,
    usage_duration      INT NOT NULL DEFAULT 0,
    price       NUMERIC(10, 2)  NOT NULL,
    expiry_date TIMESTAMP   NOT NULL,

    PRIMARY KEY (id),
    CONSTRAINT packaged_item_must_have_content_quantity
        CHECK (
            (is_whole_package = TRUE AND content_quantity IS NOT NULL)
            OR
            (is_whole_package = FALSE AND content_quantity IS NULL)
        ),
    CONSTRAINT category_limited_to_presets
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

CREATE TABLE IF NOT EXISTS prescriptions (
    visit_id    BIGINT      NOT NULL,
    item_id     BIGINT      NOT NULL,

    quantity    INT         NOT NULL,

    PRIMARY KEY (visit_id, item_id),
    FOREIGN KEY (visit_id) REFERENCES visits(id),
    FOREIGN KEY (item_id)  REFERENCES inventory(id)
);