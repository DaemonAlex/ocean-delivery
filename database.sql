CREATE TABLE IF NOT EXISTS cargo_deliveries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    player_id VARCHAR(50) NOT NULL,
    deliveries INT NOT NULL,
    distance FLOAT DEFAULT 0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
