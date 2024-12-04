/*
 Group 26 DBPRIN Coursework Database Schema
 ERD PDF: https://drive.google.com/file/d/1nB0oTYydLEmE2_XtO4u9A2eawc3cBWs-/view?usp=drive_link
 Github Repo: https://github.com/leomosley/dbprin-cw (made public after submission date)
 */

/* 
  Function to generate and return a random string of numbers - length is specified through parameter (length INT).
*/
CREATE OR REPLACE FUNCTION generate_random_string(length INT)
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
CREATE OR REPLACE FUNCTION generate_uid(length INT)
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

-- ------------------------
-- Table structure for UIDS
-- ------------------------
CREATE TABLE uid (
  uid VARCHAR(250) PRIMARY KEY
);

-- ---------------------------
-- Table structure for STUDENT
-- ---------------------------
CREATE TABLE student (
  student_id SERIAL PRIMARY KEY,
  student_edu_email CHAR(22) NOT NULL UNIQUE,
  student_number CHAR(10) NOT NULL UNIQUE,
  student_personal_email VARCHAR(150) NOT NULL UNIQUE,
  student_fname VARCHAR(50) NOT NULL,
  student_mname VARCHAR(50),
  student_lname VARCHAR(50) NOT NULL,
  student_pronouns VARCHAR(20),
  student_addr1 VARCHAR(30) NOT NULL,
  student_addr2 VARCHAR(30),
  student_city VARCHAR(30) NOT NULL,
  student_postcode VARCHAR(10) NOT NULL,
  student_landline VARCHAR(30),
  student_mobile VARCHAR(15) NOT NULL UNIQUE,
  student_dob DATE NOT NULL,
  student_attendance DECIMAL(5, 2) NOT NULL
);

/* 
 Trigger function to create the student_number, the student_edu_email using the student_number, and ensure that
 the value for student_personal_email is lowercase.
*/
CREATE OR REPLACE FUNCTION set_student_emails()
RETURNS TRIGGER AS $$
BEGIN
  NEW.student_number := CONCAT('SN', generate_uid(7));
  NEW.student_edu_email := CONCAT(NEW.student_number, '@ses.edu.org');

  IF NEW.student_personal_email IS NOT NULL THEN 
    NEW.student_personal_email := LOWER(NEW.student_personal_email);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/* 
 Trigger to insert the created student_number, student_edu_email, and updated student_personal_email into
 the student table.
*/
CREATE TRIGGER insert_student_email_trigger 
BEFORE INSERT ON student
FOR EACH ROW 
EXECUTE FUNCTION set_student_emails();

-- Functional index to enforce case insensitive uniqueness of the student personal email.
CREATE UNIQUE INDEX unique_student_personal_email_idx ON student (LOWER(student_personal_email));

CREATE INDEX idx_student_student_number ON student(student_number);

-- ---------------------------
-- Table structure for TUITION
-- ---------------------------
CREATE TABLE tuition (
  tuition_id SERIAL PRIMARY KEY,
  tuition_amount DECIMAL(7, 2) NOT NULL,
  tuition_paid DECIMAL(7, 2) NOT NULL,
  tuition_remaining DECIMAL(7, 2) NOT NULL,
  tuition_remaining_perc DECIMAL(5, 2) NOT NULL,
  tuition_deadline DATE NOT NULL,
  CONSTRAINT valid_tuition_amount CHECK (tuition_amount >= 0),
  CONSTRAINT valid_tuition_paid CHECK (tuition_paid >= 0 AND tuition_paid <= tuition_amount),
  CONSTRAINT valid_tuition_remaining CHECK (tuition_remaining >= 0 AND tuition_remaining <= tuition_amount),
  CONSTRAINT valid_tuition_remaining_perc CHECK (tuition_remaining_perc >= 0 AND tuition_remaining_perc <= 100)
);

CREATE INDEX idx_tuition_tuition_id ON tuition(tuition_id);

-- -----------------------------------
-- Table structure for STUDENT_TUITION
-- -----------------------------------
CREATE TABLE student_tuition (
  student_id INT,
  tuition_id INT,
  PRIMARY KEY (student_id, tuition_id),
  FOREIGN KEY (student_id) REFERENCES student (student_id),
  FOREIGN KEY (tuition_id) REFERENCES tuition (tuition_id)
);

CREATE INDEX idx_student_tuition_student_id ON student_tuition(student_id);

-- -----------------------------------
-- Table structure for TUITION_PAYMENT
-- -----------------------------------
CREATE TYPE payment_method_enum AS ENUM ('Credit Card', 'Debit Card', 'Direct Debit', 'Bank Transfer');

CREATE TABLE tuition_payment (
  tuition_payment_id SERIAL PRIMARY KEY,
  tuition_payment_reference CHAR(12) DEFAULT (
    CONCAT('PY', generate_uid(10))
  ) NOT NULL UNIQUE, 
  tuition_id INT,
  tuition_payment_amount DECIMAL(7, 2) NOT NULL,
  tuition_payment_date DATE NOT NULL,
  tuition_payment_method payment_method_enum NOT NULL,
  FOREIGN KEY (tuition_id) REFERENCES tuition(tuition_id)
);

/* 
  Trigger function to update the tuition after an insert into the tuition_payment table. 
  Calculates the tuition_paid, tuition_remaining, and tuition_remaining_perc. 
*/
CREATE OR REPLACE FUNCTION update_tuition_after_payment() RETURNS TRIGGER AS $$ BEGIN
  UPDATE
    tuition AS t
  SET
    tuition_paid = tuition_paid + tp.tuition_payment_amount,
    tuition_remaining = tuition_remaining - tp.tuition_payment_amount,
    tuition_remaining_perc = (
      (
        tuition_amount - (tuition_paid + tp.tuition_payment_amount)
      ) / tuition_amount
    ) * 100
  FROM
    tuition_payment AS tp
  WHERE
    tp.tuition_payment_id = NEW.tuition_payment_id
    AND t.tuition_id = NEW.tuition_id;
RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update valeus in the tuition table after insert on tuition_payment. 
CREATE TRIGGER after_student_payments_insert AFTER
INSERT ON tuition_payment FOR EACH ROW EXECUTE FUNCTION update_tuition_after_payment();

-- --------------------------
-- Table structure for BRANCH
-- --------------------------
CREATE TYPE branch_status_enum AS ENUM ('Closed', 'Open');

CREATE TABLE branch (
  branch_id SERIAL PRIMARY KEY,
  branch_name VARCHAR(50) NOT NULL,
  branch_status branch_status_enum NOT NULL,
  branch_addr1 VARCHAR(150),
  branch_addr2 VARCHAR(150),
  branch_postcode VARCHAR(10),
  branch_contact_number VARCHAR(15),
  branch_email VARCHAR(150) NOT NULL
);

-- ------------------------------
-- Table structure for DEPARTMENT
-- ------------------------------
CREATE TYPE dep_type_enum AS ENUM ('Educational', 'Administrative', 'Operational', 'Maintenance');

CREATE TABLE department (
  dep_id SERIAL PRIMARY KEY,
  branch_id INT NOT NULL,
  dep_name VARCHAR(50) NOT NULL,
  dep_type dep_type_enum NOT NULL,
  dep_description VARCHAR(200),
  FOREIGN KEY (branch_id) REFERENCES branch (branch_id)
);

-- ------------------------
-- Table structure for ROLE
-- ------------------------
CREATE TABLE role (
  role_id SERIAL PRIMARY KEY,
  role_name VARCHAR(50) NOT NULL
);

-- ----------------------------
-- Table structure for BUILDING
-- ----------------------------
CREATE TABLE building (
  building_id SERIAL PRIMARY KEY,
  branch_id INT,
  building_name VARCHAR(100) NOT NULL,
  building_alt_name VARCHAR(100),
  building_type VARCHAR(100) NOT NULL,
  building_addr1 VARCHAR(50) NOT NULL,
  building_addr2 VARCHAR(50),
  building_city VARCHAR(50) NOT NULL,
  building_postcode VARCHAR(10) NOT NULL,
  building_country VARCHAR(50) NOT NULL,
  FOREIGN KEY (branch_id) REFERENCES branch (branch_id)
);

-- ------------------------
-- Table structure for ROOM
-- ------------------------
CREATE TYPE room_type_enum AS ENUM (
  'Lecture Theatre',
  'Computer Lab',
  'Practical Room',
  'Office',
  'Seminar Room',
  'Studio',
  'Lab',
  'Meeting Room',
  'Workshop',
  'Auditorium'
);

CREATE TABLE room (
  room_id SERIAL PRIMARY KEY,
  building_id INT,
  room_name VARCHAR(100) NOT NULL,
  room_alt_name VARCHAR(100) NOT NULL,
  room_type room_type_enum NOT NULL,
  room_capacity INT NOT NULL,
  room_floor INT NOT NULL,
  FOREIGN KEY (building_id) REFERENCES building (building_id)
);

-- -------------------------
-- Table structure for STAFF
-- -------------------------
CREATE TYPE title_enum AS ENUM ('Mr', 'Mrs', 'Ms', 'Dr');

CREATE TABLE staff (
  staff_id SERIAL PRIMARY KEY,
  room_id INT,
  staff_company_email CHAR(22) UNIQUE,
  staff_personal_email VARCHAR(150) NOT NULL UNIQUE,
  staff_number CHAR(10) UNIQUE,
  staff_fname VARCHAR(50) NOT NULL,
  staff_mname VARCHAR(50),
  staff_lname VARCHAR(50) NOT NULL,
  staff_title title_enum NOT NULL,
  staff_addr1 VARCHAR(30) NOT NULL,
  staff_addr2 VARCHAR(30),
  staff_city VARCHAR(30) NOT NULL,
  staff_postcode VARCHAR(10) NOT NULL,
  staff_landline VARCHAR(30) NOT NULL,
  staff_mobile VARCHAR(15) NOT NULL,
  staff_dob DATE NOT NULL,
  phone_ext VARCHAR(50),
  FOREIGN KEY (room_id) REFERENCES room (room_id)
);

/* 
  Trigger function to create the staff_number, the staff_company_email
  using the staff_number, and ensure that the value for staff_personal_email
  is lowercase.
*/
CREATE OR REPLACE FUNCTION set_staff_emails()
RETURNS TRIGGER AS $$
BEGIN
  NEW.staff_number := LOWER(CONCAT(LEFT(NEW.staff_fname, 1), LEFT(NEW.staff_lname, 1), generate_uid(8)));
  NEW.staff_company_email := CONCAT(NEW.staff_number, '@ses.edu.org');

  IF NEW.staff_personal_email IS NOT NULL THEN 
    NEW.staff_personal_email := LOWER(NEW.staff_personal_email);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;  

/* 
  Trigger to insert the staff_number, staff_company_email, and updated 
  staff_peersonal_email into the staff table.
*/
CREATE TRIGGER insert_staff_emails_trigger
BEFORE INSERT ON staff
FOR EACH ROW
EXECUTE FUNCTION set_staff_emails();

/* 
  Functional index to enforce case insensitive uniqueness of the 
  staff personal email.
*/
CREATE UNIQUE INDEX unique_staff_personal_email_idx ON staff (LOWER(staff_personal_email));

-- -------------------------------------
-- Table structure for EMERGENCY_CONTACT
-- -------------------------------------
CREATE TABLE emergency_contact (
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
  Functional index to enforce case insensitive uniqueness of the 
  contact email.
*/
CREATE UNIQUE INDEX unique_contact_email_idx ON emergency_contact (LOWER(contact_email));

-- ---------------------------------
-- Table structure for STAFF_CONTACT
-- ---------------------------------
CREATE TABLE staff_contact (
  contact_id INT,
  staff_id INT,
  PRIMARY KEY (contact_id, staff_id),
  FOREIGN KEY (contact_id) REFERENCES emergency_contact (contact_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
);

-- -----------------------------------
-- Table structure for STUDENT_CONTACT
-- -----------------------------------
CREATE TABLE student_contact (
  contact_id INT NOT NULL,
  student_id INT NOT NULL,
  PRIMARY KEY (contact_id, student_id),
  FOREIGN KEY (contact_id) REFERENCES emergency_contact (contact_id),
  FOREIGN KEY (student_id) REFERENCES student (student_id)
);

-- ------------------------------
-- Table structure for STAFF_ROLE
-- ------------------------------
CREATE TABLE staff_role (
  staff_id INT NOT NULL,
  role_id INT NOT NULL,
  PRIMARY KEY (staff_id, role_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (role_id) REFERENCES role (role_id)
);

-- ------------------------------
-- Table structure for ASSIGNMENT
-- ------------------------------
CREATE TABLE assignment (
  assignment_id SERIAL PRIMARY KEY,
  assignment_details TEXT NOT NULL
);

-- ------------------------------------
-- Table structure for STAFF_ASSIGNMENT
-- ------------------------------------
CREATE TABLE staff_assignment (
  staff_id INT NOT NULL,
  assignment_id INT NOT NULL,
  PRIMARY KEY (staff_id, assignment_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (assignment_id) REFERENCES assignment (assignment_id)
);

-- ------------------------------------
-- Table structure for STAFF_DEPARTMENT
-- ------------------------------------
CREATE TABLE staff_department (
  staff_id INT NOT NULL,
  dep_id INT NOT NULL,
  date_assinged DATE NOT NULL,
  PRIMARY KEY (staff_id, dep_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (dep_id) REFERENCES department (dep_id)
);

-- ----------------------------
-- Table structure for FACILITY
-- ----------------------------
CREATE TABLE facility (
  facility_id SERIAL PRIMARY KEY,
  facility_total_quantity INT,
  facility_name VARCHAR(100) NOT NULL,
  facility_description TEXT,
  facility_notes TEXT NOT NULL
);

-- ---------------------------------
-- Table structure for ROOM_FACILITY
-- ---------------------------------
CREATE TABLE room_facility (
  room_id INT NOT NULL,
  facility_id INT NOT NULL,
  quantity INT NOT NULL,
  PRIMARY KEY (room_id, facility_id),
  FOREIGN KEY (room_id) REFERENCES room (room_id),
  FOREIGN KEY (facility_id) REFERENCES facility (facility_id)
);

-- --------------------------
-- Table structure for COURSE
-- --------------------------
CREATE TABLE course (
  course_id SERIAL PRIMARY KEY,
  course_code CHAR(8) NOT NULL UNIQUE,
  course_name VARCHAR(50) NOT NULL,
  course_description TEXT,
  course_entry_requirements TEXT,
  course_length SMALLINT NOT NULL
);

-- -------------------------------------
-- Table structure for DEPARTMENT_COURSE
-- -------------------------------------
CREATE TABLE department_course (
  dep_id INT NOT NULL,
  course_id INT NOT NULL,
  PRIMARY KEY (dep_id, course_id),
  FOREIGN KEY (dep_id) REFERENCES department (dep_id),
  FOREIGN KEY (course_id) REFERENCES course (course_id)
);

-- -------------------------------
-- Table structure for OFFICE_HOUR
-- -------------------------------
CREATE TABLE office_hour (
  hour_id SERIAL PRIMARY KEY,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  date DATE NOT NULL
);

-- -------------------------------------
-- Table structure for STAFF_OFFICE_HOUR
-- -------------------------------------
CREATE TABLE staff_office_hour (
  staff_id INT NOT NULL,
  hour_id INT NOT NULL,
  PRIMARY KEY (staff_id, hour_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (hour_id) REFERENCES office_hour (hour_id)
);

-- ---------------------------
-- Table structure for SESSION
-- ---------------------------
CREATE TYPE session_type_enum AS ENUM (
  'Academic Help',
  'Personal Tutor',
  'Lecture',
  'Practical'
);

CREATE TABLE session (
  session_id SERIAL PRIMARY KEY,
  room_id INT,
  session_type session_type_enum NOT NULL,
  session_start_time VARCHAR(50),
  session_end_time VARCHAR(5) NOT NULL,
  session_date VARCHAR(5) NOT NULL,
  session_feedback TEXT,
  session_mandatory BOOLEAN NOT NULL,
  session_description TEXT,
  FOREIGN KEY (room_id) REFERENCES room (room_id)
);

-- ---------------------------------
-- Table structure for STAFF_SESSION
-- ---------------------------------
CREATE TABLE staff_session (
  staff_id INT NOT NULL,
  session_id INT NOT NULL,
  PRIMARY KEY (staff_id, session_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (session_id) REFERENCES session (session_id)
);

-- ------------------------------
-- Table structure for ATTENDANCE
-- ------------------------------
CREATE TABLE attendance (
  session_id INT NOT NULL,
  student_id INT NOT NULL,
  attendance_record BOOLEAN NOT NULL,
  PRIMARY KEY (session_id, student_id),
  FOREIGN KEY (session_id) REFERENCES session (session_id),
  FOREIGN KEY (student_id) REFERENCES student (student_id)
);

-- ----------------------------------
-- Table structure for STUDENT_COURSE
-- ----------------------------------
CREATE TABLE student_course (
  student_id INT NOT NULL,
  course_id INT NOT NULL,
  progress_perc DECIMAL(5, 2) NOT NULL,
  feedback TEXT,
  culmative_average DECIMAL(5, 2) NOT NULL,
  course_rep BOOLEAN NOT NULL,
  PRIMARY KEY (student_id, course_id),
  FOREIGN KEY (student_id) REFERENCES student (student_id),
  FOREIGN KEY (course_id) REFERENCES course (course_id)
);

-- --------------------------
-- Table structure for MODULE
-- --------------------------
CREATE TABLE module (
  module_id SERIAL PRIMARY KEY,
  module_code CHAR(12) NOT NULL UNIQUE,
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
CREATE TABLE course_module (
  course_id INT NOT NULL,
  module_id INT NOT NULL,
  PRIMARY KEY (course_id, module_id),
  FOREIGN KEY (course_id) REFERENCES course (course_id),
  FOREIGN KEY (module_id) REFERENCES module (module_id)
);

-- --------------------------------------
-- Table structure for COURSE_COORDINATOR
-- --------------------------------------
CREATE TABLE course_coordinator (
  staff_id INT NOT NULL,
  course_id INT NOT NULL,
  PRIMARY KEY (staff_id, course_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (course_id) REFERENCES course (course_id)
);

-- --------------------------------------
-- Table structure for MODULE_COORDINATOR
-- --------------------------------------
CREATE TABLE module_coordinatior (
  staff_id INT NOT NULL,
  module_id INT NOT NULL,
  PRIMARY KEY (staff_id, module_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (module_id) REFERENCES module (module_id)
);

-- ----------------------------------------------
-- Table structure for STUDENT_MODULE_RESULT
-- ----------------------------------------------
CREATE TABLE student_module_result (
  student_id INT NOT NULL,
  module_id INT NOT NULL,
  module_grade VARCHAR(50) NOT NULL,
  feedback TEXT,
  passed BOOLEAN NOT NULL,
  PRIMARY KEY (student_id, module_id),
  FOREIGN KEY (student_id) REFERENCES student (student_id),
  FOREIGN KEY (module_id) REFERENCES module (module_id)
);

-- ------------------------------
-- Table structure for ASSESSMENT
-- ------------------------------
CREATE TYPE assessment_type_enum AS ENUM (
  'Exam',
  'Coursework',
  'Essay',
  'Supervised work session',
  'Presentation'
);

CREATE TABLE assessment (
  assessment_id SERIAL PRIMARY KEY,
  module_id INT,
  assessment_title VARCHAR(50) NOT NULL,
  assessment_set_date DATE NOT NULL,
  assessment_set_time TIME  NOT NULL,
  assessment_due_date DATE NOT NULL,
  assessment_due_time TIME NOT NULL,
  assessment_description TEXT,
  assessment_type assessment_type_enum NOT NULL,
  assessment_weighting DECIMAL(5, 2) NOT NULL,
  assessment_attachment TEXT,
  assessment_max_attempts INT NOT NULL,
  assessment_visble BOOLEAN NOT NULL,
  FOREIGN KEY (module_id) REFERENCES module (module_id)
);

-- --------------------------------------
-- Table structure for ASSESSMENT_ATTEMPT
-- --------------------------------------
CREATE TABLE assessment_attempt (
  attempt_id SERIAL PRIMARY KEY,
  assessment_id INT,
  attempt_grade DECIMAL(5, 2) NOT NULL,
  attempt_feedback TEXT,
  attempt_no INT NOT NULL,
  attempt_date DATE NOT NULL,
  attempt_time TIME NOT NULL,
  FOREIGN KEY (assessment_id) REFERENCES assessment (assessment_id)
);

-- ----------------------------------------------
-- Table structure for STUDENT_ASSESSMENT_ATTEMPT
-- ----------------------------------------------
CREATE TABLE student_assessment_attempt (
  student_id INT NOT NULL,
  attempt_id INT NOT NULL,
  highest_grade DECIMAL(5, 2) NOT NULL,
  feedback TEXT,
  attempts INT,
  PRIMARY KEY (student_id, attempt_id),
  FOREIGN KEY (student_id) REFERENCES student (student_id),
  FOREIGN KEY (attempt_id) REFERENCES assessment_attempt (attempt_id)
);

-- ---------
-- Views
-- ---------

CREATE VIEW student_sessions AS
SELECT 
  s.student_id,
  s.student_number,
  sn.session_type,
  sn.session_id,
  sn.session_mandatory,
  sn.session_start_time,
  sn.session_end_time,
  sn.session_date
FROM 
  student AS s
  JOIN student_course AS sc ON s.student_id = sc.student_id
  JOIN course AS c ON sc.course_id = c.course_id
  JOIN course_module AS cm ON c.course_id = cm.course_id
  JOIN module AS m ON cm.module_id = m.module_id
  JOIN session AS sn ON m.module_id = sn.module_id;

-- ---------
-- CRON Jobs
-- ---------

/*
  CRON job to update student attendance percentages
  0 * * * * 
*/
CREATE OR REPLACE FUNCTION update_attendance() RETURNS VOID AS $$
DECLARE
  student_rec RECORD;
  mandatory_count INT;
  attended_count INT;
  attendance_percentage DECIMAL;
BEGIN
  FOR student_rec IN SELECT DISTINCT student_id FROM student_sessions LOOP
      
    SELECT COUNT(*)
    INTO mandatory_count
    FROM student_sessions
    WHERE 
      student_id = student_rec.student_id 
      AND session_mandatory = TRUE;

    SELECT COUNT(*)
    INTO attended_count
    FROM student_sessions AS ss
    JOIN student_attendance AS sa ON ss.student_id = sa.student_id
    JOIN attendance AS a ON sa.attendance_id = a.attendance_id
    WHERE 
      ss.student_id = student_rec.student_id
      AND ss.session_mandatory = TRUE
      AND a.attended = TRUE;

    IF mandatory_count > 0 THEN
      attendance_percentage := (attended_count::DECIMAL / mandatory_count) * 100;
    ELSE
      attendance_percentage := 0;
    END IF;

    UPDATE student
    SET student_attendance = attendance_percentage
    WHERE student_id = student_rec.student_id;
      
  END LOOP;
END;
$$ LANGUAGE plpgsql;