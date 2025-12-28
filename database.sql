-- =============================================================================
-- Ocean Delivery Database Schema
-- Run this ONLY if auto-creation fails. Tables are created automatically on start.
-- =============================================================================

-- Player progression table
CREATE TABLE IF NOT EXISTS ocean_delivery_players (
    citizenid VARCHAR(50) PRIMARY KEY,
    xp INT DEFAULT 0,
    level INT DEFAULT 1,
    total_deliveries INT DEFAULT 0,
    total_distance FLOAT DEFAULT 0,
    total_earnings INT DEFAULT 0,
    successful_deliveries INT DEFAULT 0,
    failed_deliveries INT DEFAULT 0,
    favorite_boat VARCHAR(50) DEFAULT NULL,
    current_streak INT DEFAULT 0,
    best_streak INT DEFAULT 0,
    last_delivery TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Delivery history (can grow large - ensure indexes exist)
CREATE TABLE IF NOT EXISTS ocean_delivery_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    boat_model VARCHAR(50),
    cargo_type VARCHAR(50),
    start_port VARCHAR(100),
    end_port VARCHAR(100),
    distance FLOAT,
    payout INT,
    xp_earned INT,
    weather VARCHAR(50),
    damage_percent FLOAT DEFAULT 0,
    completion_time INT,
    status ENUM('completed', 'failed', 'cancelled') DEFAULT 'completed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_citizenid (citizenid),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Fleet ownership
CREATE TABLE IF NOT EXISTS ocean_delivery_fleet (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    boat_model VARCHAR(50) NOT NULL,
    boat_name VARCHAR(100) DEFAULT NULL,
    condition_percent FLOAT DEFAULT 100.0,
    fuel_level FLOAT DEFAULT 100.0,
    total_deliveries INT DEFAULT 0,
    total_distance FLOAT DEFAULT 0,
    purchase_price INT DEFAULT 0,
    insured BOOLEAN DEFAULT FALSE,
    is_starter BOOLEAN DEFAULT FALSE,
    last_maintenance TIMESTAMP NULL,
    purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_citizenid (citizenid),
    INDEX idx_model (boat_model)
);

-- Maintenance log
CREATE TABLE IF NOT EXISTS ocean_delivery_maintenance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fleet_id INT NOT NULL,
    citizenid VARCHAR(50) NOT NULL,
    maintenance_type ENUM('repair', 'insurance', 'routine') DEFAULT 'routine',
    cost INT DEFAULT 0,
    notes VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fleet (fleet_id),
    INDEX idx_citizenid (citizenid)
);

-- Encounters log
CREATE TABLE IF NOT EXISTS ocean_delivery_encounters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    encounter_type VARCHAR(50) NOT NULL,
    outcome ENUM('success', 'failed', 'escaped', 'caught', 'abandoned') DEFAULT 'success',
    reward INT DEFAULT 0,
    xp_earned INT DEFAULT 0,
    cargo_type VARCHAR(50) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_citizenid (citizenid)
);

-- Boat loans/financing
CREATE TABLE IF NOT EXISTS ocean_delivery_loans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    fleet_id INT NOT NULL,
    boat_model VARCHAR(50) NOT NULL,
    total_amount INT NOT NULL,
    down_payment INT NOT NULL,
    financed_amount INT NOT NULL,
    interest_rate FLOAT NOT NULL,
    weekly_payment INT NOT NULL,
    weeks_total INT NOT NULL,
    weeks_paid INT DEFAULT 0,
    amount_paid INT DEFAULT 0,
    amount_remaining INT NOT NULL,
    missed_payments INT DEFAULT 0,
    status ENUM('active', 'paid', 'defaulted', 'repossessed') DEFAULT 'active',
    next_payment_due TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_off_at TIMESTAMP NULL,
    INDEX idx_citizenid (citizenid),
    INDEX idx_fleet (fleet_id),
    INDEX idx_status (status)
);

-- Custom cargo locations
CREATE TABLE IF NOT EXISTS cargo_locations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    x FLOAT NOT NULL,
    y FLOAT NOT NULL,
    z FLOAT NOT NULL,
    tier INT DEFAULT 1,
    has_fuel BOOLEAN DEFAULT FALSE,
    enabled BOOLEAN DEFAULT TRUE,
    added_by VARCHAR(50),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- MAINTENANCE QUERIES (Run periodically on high-traffic servers)
-- =============================================================================

-- Add index to history table if missing (for date range queries)
-- ALTER TABLE ocean_delivery_history ADD INDEX idx_created_at (created_at);

-- Cleanup old history (keep last 30 days, run weekly)
-- DELETE FROM ocean_delivery_history WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Optimize tables after bulk deletes
-- OPTIMIZE TABLE ocean_delivery_history;
