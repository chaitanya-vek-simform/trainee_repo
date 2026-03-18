-- Database Creation
CREATE DATABASE IF NOT EXISTS trainee_db;

USE trainee_db;

-- Table Creation
CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    department TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Example Data (Optional)
INSERT INTO students (name, department) VALUES 
('Alice Smith', 'Computer Science'),
('Bob Johnson', 'Mechanical Engineering');
