/*
  SHARED SCHEMA
*/

CREATE SCHEMA shared;

/* 
  Function to generate and return a random string of numbers - length is specified through parameter (length INT).
*/
CREATE OR REPLACE FUNCTION shared.generate_random_string(length INT)
RETURNS VARCHAR AS $$
DECLARE
  string VARCHAR;
BEGIN
  string := '';
  FOR i IN 1..length LOOP
    string := CONCAT(string, to_char(floor(random() * 10), 'FM0'));
  END LOOP;

  RETURN string;
END;
$$ LANGUAGE plpgsql;

/* 
  Function to generate and return a unique identifier of length specified through parameter (length INT).

  Uses the UID table to store all generated uids to ensure that they are all unique. 
*/
CREATE OR REPLACE FUNCTION shared.generate_uid(length INT)
RETURNS VARCHAR AS $$
DECLARE
  string VARCHAR;
BEGIN
  string := generate_random_string(length);

  WHILE EXISTS (SELECT uid FROM uid WHERE uid = string) LOOP
    string := generate_random_string(length);
  END LOOP;

  INSERT INTO uid (uid) VALUES (string);

  RETURN string;
END;
$$ LANGUAGE plpgsql;

/* 
  Shared ENUMS
*/
CREATE TYPE shared.branch_status_enum AS ENUM ('Closed', 'Open');

CREATE TYPE shared.dep_type_enum AS ENUM ('Educational', 'Administrative', 'Operational', 'Maintenance');

CREATE TYPE shared.assessment_type_enum AS ENUM (
  'Exam',
  'Coursework',
  'Essay',
  'Supervised work session',
  'Presentation'
);

CREATE TYPE shared.title_enum AS ENUM ('Mr', 'Mrs', 'Ms', 'Dr');

-- -----------------------
-- Table structure for UID
-- -----------------------
CREATE TABLE shared.uid (
  uid VARCHAR(250) PRIMARY KEY
);

-- --------------------------
-- Table structure for BRANCH
-- --------------------------
CREATE TABLE shared.branch (
  branch_id CHAR(3) DEFAULT (
    CONCAT('B', shared.generate_uid(2))
  ) PRIMARY KEY,
  branch_name VARCHAR(50) NOT NULL,
  branch_status shared.branch_status_enum NOT NULL,
  branch_addr1 VARCHAR(150),
  branch_addr2 VARCHAR(150),
  branch_postcode VARCHAR(10),
  branch_contact_number VARCHAR(15),
  branch_email VARCHAR(150) NOT NULL
);

-- ------------------------------
-- Table structure for DEPARTMENT
-- ------------------------------
CREATE TABLE shared.department (
  dep_id char(7) DEFAULT (
    CONCAT('D', shared.generate_uid(6))
  ) PRIMARY KEY,
  dep_name VARCHAR(50) NOT NULL,
  dep_type shared.dep_type_enum NOT NULL,
  dep_description VARCHAR(200)
);

-- --------------------------
-- Table structure for COURSE
-- --------------------------
CREATE TABLE shared.course (
  course_id CHAR(7) DEFAULT (
    CONCAT('C', shared.generate_uid(6))
  ) PRIMARY KEY,
  course_code CHAR(8) NOT NULL UNIQUE,
  course_name VARCHAR(50) NOT NULL,
  course_description TEXT,
  course_entry_requirements TEXT,
  course_length SMALLINT NOT NULL
);

-- -------------------------------------
-- Table structure for DEPARTMENT_COURSE
-- -------------------------------------
CREATE TABLE shared.department_course (
  dep_id CHAR(7) NOT NULL,
  course_id CHAR(7) NOT NULL,
  PRIMARY KEY (dep_id, course_id),
  FOREIGN KEY (dep_id) REFERENCES shared.department (dep_id),
  FOREIGN KEY (course_id) REFERENCES shared.course (course_id)
);

-- --------------------------
-- Table structure for MODULE
-- --------------------------
CREATE TABLE shared.module (
  module_id CHAR(7) DEFAULT (
    CONCAT('M', shared.generate_uid(6))
  ) PRIMARY KEY,
  module_name VARCHAR(50) NOT NULL,
  module_description TEXT,
  academ_lvl CHAR(2) NOT NULL,
  module_credits INT NOT NULL,
  module_status VARCHAR(20) NOT NULL,
  last_reviewed DATE NOT NULL,
  notional_hours DECIMAL(5, 2) NOT NULL,
  module_duration INT NOT NULL
);

-- ----------------------------------
-- Table structure for COURSE_MODULE
-- ----------------------------------
CREATE TABLE shared.course_module (
  course_id CHAR(7) NOT NULL,
  module_id CHAR(7) NOT NULL,
  PRIMARY KEY (course_id, module_id),
  FOREIGN KEY (course_id) REFERENCES shared.course (course_id),
  FOREIGN KEY (module_id) REFERENCES shared.module (module_id)
);

-- ------------------------------
-- Table structure for ASSESSMENT
-- ------------------------------
CREATE TABLE shared.assessment (
  assessment_id CHAR(10) DEFAULT (
    CONCAT('A', shared.generate_uid(9))
  ) PRIMARY KEY,
  module_id CHAR(7) NOT NULL,
  assessment_title VARCHAR(50) NOT NULL,
  assessment_set_date DATE NOT NULL,
  assessment_set_time TIME  NOT NULL,
  assessment_due_date DATE NOT NULL,
  assessment_due_time TIME NOT NULL,
  assessment_description TEXT,
  assessment_type shared.assessment_type_enum NOT NULL,
  assessment_weighting DECIMAL(5, 2) NOT NULL,
  assessment_attachment TEXT,
  assessment_max_attempts INT NOT NULL,
  assessment_visble BOOLEAN NOT NULL,
  FOREIGN KEY (module_id) REFERENCES shared.module (module_id)
);

-- ------------------------
-- Table structure for ROLE
-- ------------------------
CREATE TABLE shared.role (
  role_id SERIAL PRIMARY KEY,
  role_name VARCHAR(50) NOT NULL
);

-- ----------------------------
-- Table structure for FACILITY
-- ----------------------------
CREATE TABLE shared.facility (
  facility_id SERIAL PRIMARY KEY,
  facility_total_quantity INT,
  facility_name VARCHAR(100) NOT NULL,
  facility_description TEXT,
  facility_notes TEXT NOT NULL
);

-- -------------------------------------
-- Table structure for EMERGENCY_CONTACT
-- -------------------------------------
CREATE TABLE shared.emergency_contact (
  contact_id SERIAL PRIMARY KEY,
  contact_email VARCHAR(150) NOT NULL UNIQUE,
  contact_phone CHAR(15) NOT NULL UNIQUE,
  contact_fname VARCHAR(100) NOT NULL,
  contact_wname VARCHAR(100),
  contact_lname VARCHAR(100) NOT NULL,
  contact_addr1 VARCHAR(150) NOT NULL,
  contact_addr2 VARCHAR(150),
  contact_city VARCHAR(100) NOT NULL,
  contact_postcode VARCHAR(10) NOT NULL,
  contact_relationship VARCHAR(50) NOT NULL
);

/*
  For generating new schema on insert
*/
CREATE OR REPLACE FUNCTION shared.create_branch_schema()
RETURNS TRIGGER AS $$
DECLARE
  schema_name TEXT;
BEGIN
  schema_name := NEW.branch_id;

  EXECUTE format('CREATE SCHEMA IF NOT EXISTS branch_%I', branch_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_create_branch_schema
AFTER INSERT
ON shared.branch
FOR EACH ROW
EXECUTE FUNCTION shared.create_branch_schema();