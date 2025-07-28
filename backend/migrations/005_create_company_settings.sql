-- Create company settings table
CREATE TABLE IF NOT EXISTS company_settings (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(50),
  address TEXT,
  logo_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert default settings
INSERT INTO company_settings (name, email, phone, address) 
VALUES ('Q''BellaJoyeria', 'info@qbellajoyeria.com', '(01) 123-4567', 'Av. Principal 123, Lima')
ON DUPLICATE KEY UPDATE id=id;