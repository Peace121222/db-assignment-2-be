CREATE DATABASE IF NOT EXISTS db_assignment_2
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE db_assignment_2;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS
    ADDRESS,
    REVIEW_MEDIA,
    PRODUCT_MEDIA,
    RETURN_REQUEST,
    REVIEW,
    SHIPMENT,
    PAYMENT,
    ORDER_ITEM,
    CUSTOMER_ORDER,
    CART_ITEM,
    CART,
    PROMOTION_ITEM,
    CAMPAIGN,
    VOUCHER_WALLET,
    VOUCHER,
    PRODUCT_VARIANT,
    PRODUCT,
    STORE,
    CATEGORY,
    ADMIN,
    SELLER,
    BUYER,
    USER_ACCOUNT;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================================
-- 1) USER / ROLE TABLES
-- =========================================================

CREATE TABLE USER_ACCOUNT (
    account_id VARCHAR(36) PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(15),
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL
);

-- Address is kept as a separate table to normalize the composite address
-- from Assignment 1 and support multiple delivery addresses per account.
CREATE TABLE ADDRESS (
    address_id VARCHAR(36) PRIMARY KEY,
    account_id VARCHAR(36) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL,
    house_num VARCHAR(20),
    street VARCHAR(100),
    ward VARCHAR(50),
    district VARCHAR(50),
    is_default BOOLEAN DEFAULT FALSE,
    type ENUM('home', 'office') DEFAULT 'home',
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (account_id) REFERENCES USER_ACCOUNT(account_id) ON DELETE CASCADE
);

CREATE TABLE BUYER (
    account_id VARCHAR(36) PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    loyalty_points INT DEFAULT 0 CHECK (loyalty_points >= 0),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (account_id) REFERENCES USER_ACCOUNT(account_id) ON DELETE CASCADE
);

CREATE TABLE SELLER (
    account_id VARCHAR(36) PRIMARY KEY,
    shop_name VARCHAR(100) NOT NULL,
    tax_id VARCHAR(20) UNIQUE,
    is_verified BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (account_id) REFERENCES USER_ACCOUNT(account_id) ON DELETE CASCADE
);

CREATE TABLE ADMIN (
    account_id VARCHAR(36) PRIMARY KEY,
    employee_code VARCHAR(20) UNIQUE NOT NULL,
    role VARCHAR(50),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (account_id) REFERENCES USER_ACCOUNT(account_id) ON DELETE CASCADE
);

-- =========================================================
-- 2) CATEGORY / STORE / PRODUCT
-- =========================================================

CREATE TABLE CATEGORY (
    category_id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    parent_id VARCHAR(36) NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (parent_id) REFERENCES CATEGORY(category_id),
    CONSTRAINT chk_category_parent CHECK (
        parent_id IS NULL OR parent_id <> category_id
    )
);

CREATE TABLE STORE (
    store_id VARCHAR(36) PRIMARY KEY,
    seller_id VARCHAR(36) NOT NULL,
    store_name VARCHAR(100) NOT NULL,
    rating DECIMAL(3,2) DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (seller_id) REFERENCES SELLER(account_id)
);

CREATE TABLE PRODUCT (
    product_id VARCHAR(36) PRIMARY KEY,
    store_id VARCHAR(36) NOT NULL,
    category_id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    base_price DECIMAL(15,2) NOT NULL CHECK (base_price >= 0),
    status ENUM('active', 'out_of_stock', 'hidden') DEFAULT 'active',
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (store_id) REFERENCES STORE(store_id),
    FOREIGN KEY (category_id) REFERENCES CATEGORY(category_id)
);

CREATE TABLE PRODUCT_VARIANT (
    variant_id VARCHAR(36) PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    sku VARCHAR(50) UNIQUE,
    options VARCHAR(255),
    price_adj DECIMAL(15,2) DEFAULT 0 CHECK (price_adj >= 0),
    stock INT DEFAULT 0 CHECK (stock >= 0),
    variant_image_url VARCHAR(255),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (product_id) REFERENCES PRODUCT(product_id) ON DELETE CASCADE
);

CREATE TABLE PRODUCT_MEDIA (
    media_id VARCHAR(36) PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    url VARCHAR(255) NOT NULL,
    type ENUM('image', 'video') DEFAULT 'image',
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (product_id) REFERENCES PRODUCT(product_id) ON DELETE CASCADE
);

-- =========================================================
-- 3) VOUCHER / CAMPAIGN / PROMOTION
-- =========================================================

CREATE TABLE VOUCHER (
    voucher_id VARCHAR(36) PRIMARY KEY,
    store_id VARCHAR(36) NULL,
    code VARCHAR(20) UNIQUE NOT NULL,
    discount_type ENUM('fixed', 'percent') NOT NULL,
    discount_val DECIMAL(15,2) NOT NULL,
    max_discount_val DECIMAL(15,2),
    min_spend DECIMAL(15,2) DEFAULT 0,
    usage_limit INT DEFAULT 100,
    usage_count INT DEFAULT 0 CHECK (usage_count >= 0 AND usage_count <= usage_limit),
    exp_date DATETIME,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (store_id) REFERENCES STORE(store_id),
    CONSTRAINT chk_voucher_discount CHECK (
        (discount_type = 'percent' AND discount_val > 0 AND discount_val <= 100)
        OR
        (discount_type = 'fixed' AND discount_val > 0)
    )
);

CREATE TABLE VOUCHER_WALLET (
    buyer_id VARCHAR(36) NOT NULL,
    voucher_id VARCHAR(36) NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (buyer_id, voucher_id),
    FOREIGN KEY (buyer_id) REFERENCES BUYER(account_id),
    FOREIGN KEY (voucher_id) REFERENCES VOUCHER(voucher_id)
);

CREATE TABLE CAMPAIGN (
    campaign_id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    start_at DATETIME,
    end_at DATETIME,
    created_by VARCHAR(36),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (created_by) REFERENCES ADMIN(account_id),
    CONSTRAINT chk_campaign_date CHECK (start_at < end_at)
);

CREATE TABLE PROMOTION_ITEM (
    campaign_id VARCHAR(36),
    product_id VARCHAR(36),
    promo_price DECIMAL(15,2) CHECK (promo_price >= 0),
    campaign_stock_limit INT DEFAULT 0 CHECK (campaign_stock_limit >= 0),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (campaign_id, product_id),
    FOREIGN KEY (campaign_id) REFERENCES CAMPAIGN(campaign_id),
    FOREIGN KEY (product_id) REFERENCES PRODUCT(product_id)
);

-- =========================================================
-- 4) CART / ORDER / PAYMENT / SHIPMENT
-- =========================================================

CREATE TABLE CART (
    cart_id VARCHAR(36) PRIMARY KEY,
    buyer_id VARCHAR(36) UNIQUE NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (buyer_id) REFERENCES BUYER(account_id)
);

CREATE TABLE CART_ITEM (
    cart_id VARCHAR(36),
    variant_id VARCHAR(36),
    quantity INT DEFAULT 1 CHECK (quantity > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (cart_id, variant_id),
    FOREIGN KEY (cart_id) REFERENCES CART(cart_id),
    FOREIGN KEY (variant_id) REFERENCES PRODUCT_VARIANT(variant_id)
);

CREATE TABLE CUSTOMER_ORDER (
    order_id VARCHAR(36) PRIMARY KEY,
    buyer_id VARCHAR(36) NOT NULL,
    store_id VARCHAR(36) NOT NULL,
    order_sn VARCHAR(32) UNIQUE,
    total_amount DECIMAL(15,2) DEFAULT 0 CHECK (total_amount >= 0),
    shipping_fee DECIMAL(15,2) DEFAULT 0 CHECK (shipping_fee >= 0),
    shipping_address_snapshot JSON NOT NULL,
    status ENUM('pending', 'paid', 'shipping', 'completed', 'cancelled') DEFAULT 'pending',
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES BUYER(account_id),
    FOREIGN KEY (store_id) REFERENCES STORE(store_id)
);

CREATE TABLE ORDER_ITEM (
    order_id VARCHAR(36),
    variant_id VARCHAR(36),
    quantity INT NOT NULL CHECK (quantity > 0),
    original_price DECIMAL(15,2) NOT NULL CHECK (original_price >= 0),
    discount_amount DECIMAL(15,2) DEFAULT 0 CHECK (discount_amount >= 0),
    price_at_buy DECIMAL(15,2) NOT NULL CHECK (price_at_buy >= 0),
    voucher_id VARCHAR(36) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, variant_id),
    FOREIGN KEY (order_id) REFERENCES CUSTOMER_ORDER(order_id),
    FOREIGN KEY (variant_id) REFERENCES PRODUCT_VARIANT(variant_id),
    FOREIGN KEY (voucher_id) REFERENCES VOUCHER(voucher_id)
);

CREATE TABLE PAYMENT (
    payment_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36) UNIQUE,
    method ENUM('cod', 'e-wallet', 'credit_card'),
    amount DECIMAL(15,2) NOT NULL CHECK (amount >= 0),
    status ENUM('pending', 'success', 'failed') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES CUSTOMER_ORDER(order_id)
);

CREATE TABLE SHIPMENT (
    shipment_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36) UNIQUE,
    tracking_num VARCHAR(50) UNIQUE,
    carrier VARCHAR(50),
    status ENUM('packing', 'shipping', 'delivered'),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES CUSTOMER_ORDER(order_id)
);

-- =========================================================
-- 5) REVIEW / RETURN REQUEST
-- =========================================================

CREATE TABLE REVIEW (
    review_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36),
    variant_id VARCHAR(36),
    buyer_id VARCHAR(36),
    rating TINYINT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (order_id, variant_id) REFERENCES ORDER_ITEM(order_id, variant_id),
    FOREIGN KEY (buyer_id) REFERENCES BUYER(account_id),
    CONSTRAINT uq_review_order_variant UNIQUE (order_id, variant_id)
);

CREATE TABLE REVIEW_MEDIA (
    media_id VARCHAR(36) PRIMARY KEY,
    review_id VARCHAR(36),
    url VARCHAR(255),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (review_id) REFERENCES REVIEW(review_id) ON DELETE CASCADE
);

CREATE TABLE RETURN_REQUEST (
    request_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL,
    variant_id VARCHAR(36) NOT NULL,
    admin_id VARCHAR(36) NULL,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    requested_refund_amount DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (requested_refund_amount >= 0),
    reason TEXT,
    handling_result TEXT,
    status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id, variant_id) REFERENCES ORDER_ITEM(order_id, variant_id),
    FOREIGN KEY (admin_id) REFERENCES ADMIN(account_id)
);

-- =========================================================
-- 6) INDEXES
-- =========================================================

CREATE INDEX idx_address_account ON ADDRESS(account_id);

CREATE INDEX idx_store_seller ON STORE(seller_id);

CREATE INDEX idx_product_store ON PRODUCT(store_id);
CREATE INDEX idx_product_category ON PRODUCT(category_id);
CREATE INDEX idx_product_status_deleted ON PRODUCT(status, is_deleted);

CREATE INDEX idx_variant_product ON PRODUCT_VARIANT(product_id);
CREATE INDEX idx_variant_deleted_stock ON PRODUCT_VARIANT(is_deleted, stock);

CREATE INDEX idx_voucher_store ON VOUCHER(store_id);
CREATE INDEX idx_voucher_exp_date ON VOUCHER(exp_date);

CREATE INDEX idx_campaign_creator ON CAMPAIGN(created_by);

CREATE INDEX idx_order_buyer ON CUSTOMER_ORDER(buyer_id);
CREATE INDEX idx_order_store ON CUSTOMER_ORDER(store_id);
CREATE INDEX idx_order_status_deleted ON CUSTOMER_ORDER(status, is_deleted);

CREATE INDEX idx_orderitem_variant ON ORDER_ITEM(variant_id);
CREATE INDEX idx_orderitem_voucher ON ORDER_ITEM(voucher_id);

CREATE INDEX idx_payment_order_status ON PAYMENT(order_id, status);
CREATE INDEX idx_shipment_order_status ON SHIPMENT(order_id, status);

CREATE INDEX idx_review_buyer ON REVIEW(buyer_id);

CREATE INDEX idx_return_admin ON RETURN_REQUEST(admin_id);
CREATE INDEX idx_return_status ON RETURN_REQUEST(status);