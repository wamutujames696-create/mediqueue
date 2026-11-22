CREATE DATABASE IF NOT EXISTS `22_mediqueue` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `22_mediqueue`;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  google_sub VARCHAR(255) NULL UNIQUE,
  full_name VARCHAR(160) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  phone VARCHAR(30) NULL,
  role ENUM('patient','staff','admin') NOT NULL DEFAULT 'patient',
  status ENUM('Pending','Approved','Active','Suspended') NOT NULL DEFAULT 'Active',
  auth_provider ENUM('google','local') NOT NULL DEFAULT 'google',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_role_status (role,status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS departments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  ticket_prefix VARCHAR(5) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS queue_tickets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  department_id BIGINT UNSIGNED NOT NULL,
  ticket_number VARCHAR(30) NOT NULL UNIQUE,
  queue_status ENUM('Waiting','Serving','Completed','Cancelled') NOT NULL DEFAULT 'Waiting',
  issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  called_at DATETIME NULL,
  completed_at DATETIME NULL,
  CONSTRAINT fk_ticket_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_ticket_department FOREIGN KEY (department_id) REFERENCES departments(id),
  INDEX idx_ticket_queue (department_id,queue_status,issued_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS appointments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id BIGINT UNSIGNED NOT NULL,
  department_id BIGINT UNSIGNED NOT NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  notes TEXT NULL,
  status ENUM('Pending','Confirmed','Rejected','Completed','Cancelled') NOT NULL DEFAULT 'Pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_appointment_patient FOREIGN KEY (patient_id) REFERENCES users(id),
  CONSTRAINT fk_appointment_department FOREIGN KEY (department_id) REFERENCES departments(id),
  INDEX idx_appointment_schedule (appointment_date,appointment_time,status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS health_profiles (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  date_of_birth DATE NULL,
  blood_group VARCHAR(5) NULL,
  allergies TEXT NULL,
  medical_notes TEXT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_health_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  title VARCHAR(180) NOT NULL,
  message TEXT NOT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_notification_user (user_id,is_read,created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS staff_tasks (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  assigned_to BIGINT UNSIGNED NOT NULL,
  title VARCHAR(180) NOT NULL,
  description TEXT NULL,
  task_status ENUM('Open','In Progress','Completed') NOT NULL DEFAULT 'Open',
  due_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_task_staff FOREIGN KEY (assigned_to) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS support_requests (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  topic VARCHAR(120) NOT NULL,
  message TEXT NOT NULL,
  request_status ENUM('Open','In Progress','Closed') NOT NULL DEFAULT 'Open',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_support_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

INSERT IGNORE INTO departments (name,ticket_prefix) VALUES
('General Medicine','G'),('Paediatrics','P'),('Dental Clinic','D'),('Maternity','M');
