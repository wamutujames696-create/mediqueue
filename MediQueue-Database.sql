-- 22 MediQueue database
-- MySQL 8.0+ / MariaDB 10.5+
-- Create/import this file in phpMyAdmin.
CREATE DATABASE IF NOT EXISTS mediqueue
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mediqueue;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  username VARCHAR(60) UNIQUE,
  email VARCHAR(190) NOT NULL UNIQUE,
  phone VARCHAR(30),
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('patient','staff','admin') NOT NULL DEFAULT 'patient',
  department_id BIGINT UNSIGNED NULL,
  profile_photo VARCHAR(500),
  account_status ENUM('Pending','Approved','Suspended') NOT NULL DEFAULT 'Approved',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_role_status (role, account_status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS departments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  queue_prefix VARCHAR(5) NOT NULL UNIQUE,
  service_desk VARCHAR(80) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

ALTER TABLE users
  ADD CONSTRAINT fk_users_department
  FOREIGN KEY (department_id) REFERENCES departments(id)
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS doctor_contacts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  display_name VARCHAR(150) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  email VARCHAR(190),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_contacts_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS queue_counters (
  department_id BIGINT UNSIGNED PRIMARY KEY,
  current_number INT UNSIGNED NOT NULL DEFAULT 0,
  now_serving INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_counter_department FOREIGN KEY (department_id) REFERENCES departments(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS queue_tickets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ticket_code VARCHAR(20) NOT NULL UNIQUE,
  patient_id BIGINT UNSIGNED NOT NULL,
  department_id BIGINT UNSIGNED NOT NULL,
  visit_reason VARCHAR(500),
  ticket_status ENUM('Waiting','Serving','Completed','Cancelled','Missed') NOT NULL DEFAULT 'Waiting',
  issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  called_at DATETIME NULL,
  completed_at DATETIME NULL,
  CONSTRAINT fk_ticket_patient FOREIGN KEY (patient_id) REFERENCES users(id),
  CONSTRAINT fk_ticket_department FOREIGN KEY (department_id) REFERENCES departments(id),
  INDEX idx_queue_department_status (department_id, ticket_status, issued_at),
  INDEX idx_queue_patient (patient_id, issued_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS appointments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id BIGINT UNSIGNED NOT NULL,
  department_id BIGINT UNSIGNED NOT NULL,
  doctor_id BIGINT UNSIGNED NULL,
  preferred_date DATE NOT NULL,
  preferred_time TIME NOT NULL,
  patient_notes VARCHAR(1000),
  appointment_status ENUM('Pending','Confirmed','Rescheduled','Completed','Cancelled','Rejected') NOT NULL DEFAULT 'Pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_appointment_patient FOREIGN KEY (patient_id) REFERENCES users(id),
  CONSTRAINT fk_appointment_department FOREIGN KEY (department_id) REFERENCES departments(id),
  CONSTRAINT fk_appointment_doctor FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_appointment_date_status (preferred_date, appointment_status),
  INDEX idx_appointment_patient (patient_id, preferred_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS patient_health_profiles (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id BIGINT UNSIGNED NOT NULL UNIQUE,
  age_range VARCHAR(30),
  preferred_department_id BIGINT UNSIGNED NULL,
  allergy_note VARCHAR(1000),
  general_note TEXT,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_health_patient FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_health_department FOREIGN KEY (preferred_department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(180) NOT NULL,
  message VARCHAR(1000) NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_notifications_user_read (user_id, is_read, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS support_requests (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  contact_name VARCHAR(150),
  contact_email VARCHAR(190),
  topic VARCHAR(120) NOT NULL,
  message TEXT NOT NULL,
  request_status ENUM('Open','In Progress','Resolved','Closed') NOT NULL DEFAULT 'Open',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_support_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS staff_tasks (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  assigned_to BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NULL,
  task_status ENUM('Open','In Progress','Completed','Cancelled') NOT NULL DEFAULT 'Open',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_at DATETIME NULL,
  CONSTRAINT fk_task_assignee FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_task_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS wellness_requests (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id BIGINT UNSIGNED NULL,
  requester_name VARCHAR(150) NOT NULL,
  preferred_contact VARCHAR(190),
  connection_method VARCHAR(100),
  question TEXT NOT NULL,
  request_status ENUM('New','Contacted','Closed') NOT NULL DEFAULT 'New',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_wellness_patient FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Initial departments matching the MediQueue demo.
INSERT IGNORE INTO departments (name, queue_prefix, service_desk) VALUES
('General Medicine','G','Desk 02'),
('Paediatrics','P','Desk 03'),
('Dental Care','D','Desk 04'),
('Maternity','M','Desk 05'),
('Laboratory','L','Desk 06'),
('Pharmacy','PH','Desk 07');

INSERT IGNORE INTO queue_counters (department_id)
SELECT id FROM departments;

-- Security notes:
-- 1) Store passwords using PHP password_hash(); never store plain text.
-- 2) Use prepared statements and role checks on every protected endpoint.
-- 3) Restrict access to health-profile data; collect only what is necessary.
-- 4) This schema creates the database only. Existing browser localStorage
--    code must be replaced with PHP/API requests to persist data here.
