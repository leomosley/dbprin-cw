/*
Group 26 DBPRIN Coursework Database Schema
ERD PDF: https://drive.google.com/file/d/1nB0oTYydLEmE2_XtO4u9A2eawc3cBWs-/view?usp=drive_link
Github Repo: https://github.com/leomosley/dbprin-cw
 */
CREATE TABLE
  branch (
    branch_id serial PRIMARY KEY NOT NULL,
    branch_name VARCHAR(50) NOT NULL,
    branch_status ENUM NOT NULL,
    branch_addr1 VARCHAR(150),
    branch_addr2 VARCHAR(150),
    branch_postcode VARCHAR(10),
    branch_contact_number VARCHAR(15),
    branch_email VARCHAR(150) NOT NULL,
  );

CREATE TABLE
  department (
    dep_id serial PRIMARY KEY NOT NULL,
    dep_name VARCHAR(50) NOT NULL,
    dep_type ENUM,
    dep_description VARCHAR(200)
  );

CREATE TABLE
  branch_department (
    branch_id INT NOT NULL,
    dep_id INT NOT NULL,
    PRIMARY KEY (branch_id, dep_id),
    CONSTRAINT fk_branch FOREIGN KEY (branch_id) REFERENCES branch (branch_id),
    CONSTRAINT fk_department FOREIGN KEY (dep_id) REFERENCES department (dep_id)
  );

CREATE TABLE
  role (
    role_id serial PRIMARY KEY NOT NULL,
    role_name VARCHAR(50) NOT NULL
  );

CREATE TABLE
  staff (
    staff_id SERIAL PRIMARY KEY,
    staff_company_email CHAR(22),
    staff_number CHAR(10) NOT NULL,
    staff_fname VARCHAR(50) NOT NULL,
    staff_mname VARCHAR(50),
    staff_lname VARCHAR(50) NOT NULL,
    staff_title ENUM,
    staff_addr1 VARCHAR(30) NOT NULL,
    staff_addr2 VARCHAR(30),
    staff_city VARCHAR(30) NOT NULL,
    staff_postcode VARCHAR(10) NOT NULL,
    staff_personal_email VARCHAR(150) NOT NULL,
    staff_landline VARCHAR(30) NOT NULL,
    staff_mobile VARCHAR(15) NOT NULL,
    staff_dob DATE NOT NULL,
    UNIQUE (staff_company_email, staff_number)
  );

CREATE TABLE
  staff_contact (
    contact_id INT NOT NULL,
    staff_id INT NOT NULL,
    PRIMARY KEY (contact_id, staff_id),
    CONSTRAINT fk_emergency_contact FOREIGN KEY (contact_id) REFERENCES emergency_contact (contact_id),
    CONSTRAINT fk_staff FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
  );

CREATE TABLE
  emergency_contact (
    contact_id SERIAL PRIMARY KEY NOT NULL,
    contact_email VARCHAR(150) NOT NULL,
    contact_phone CHAR(15) NOT NULL,
    contact_fname VARCHAR(100) NOT NULL,
    contact_wname VARCHAR(100),
    contact_lname VARCHAR(100) NOT NULL,
    contact_addr1 VARCHAR(150) NOT NULL,
    contact_addr2 VARCHAR(150),
    contact_city VARCHAR(100) NOT NULL,
    contact_postcode VARCHAR(10) NOT NULL,
    contact_relationship VARCHAR(50) NOT NULL,
    UNIQUE (contact_email, contact_phone)
  );

CREATE TABLE
  staff_role (
    staff_id INT NOT NULL,
    role_id INT NOT NULL,
    PRIMARY KEY (staff_id, role_id),
    CONSTRAINT fk_staff FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
    CONSTRAINT fk_role FOREIGN KEY (role_id) REFERENCES role (role_id)
  );

CREATE TABLE
  staff_assignment (
    staff_id INT NOT NULL,
    assignment_id INT NOT NULL,
    PRIMARY KEY (staff_id, assignment_id),
    CONSTRAINT fk_staff FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
    CONSTRAINT fk_assignment FOREIGN KEY (assignment_id) REFERENCES assignment (assignment_id)
  );

CREATE TABLE
  assignment (
    assignment_id serial PRIMARY KEY NOT NULL,
    assignment_details TEXT NOT NULL
  );

CREATE TABLE
  staff_department (
    staff_id INT NOT NULL,
    dep_id INT NOT NULL,
    PRIMARY KEY (staff_id, dep_id),
    CONSTRAINT fk_staff FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
    CONSTRAINT fk_department FOREIGN KEY (dep_id) REFERENCES department (dep_id)
  );

CREATE TABLE
  building (
    building_id serial PRIMARY KEY NOT NULL,
    branch_id INT,
    CONSTRAINT fk_branch_id FOREIGN KEY (branch_id) REFERENCES branch (branch_id),
    building_name VARCHAR(100) NOT NULL,
    building_alt_name VARCHAR(100),
    building_type VARCHAR(100) NOT NULL,
    building_addr1 VARCHAR(50) NOT NULL,
    building_addr2 VARCHAR(50),
    building_city VARCHAR(50) NOT NULL,
    building_postcode VARCHAR(10) NOT NULL,
    building_country VARCHAR(50) NOT NULL
  );

CREATE TABLE
  department_course (
    dep_id INT NOT NULL,
    course_id INT NOT NULL,
    PRIMARY KEY (dep_id, course_id),
    CONSTRAINT fk_department FOREIGN KEY (dep_id) REFERENCES department (dep_id),
    CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES course (course_id)
  );

CREATE TABLE
  course (
    course_id serial PRIMARY KEY NOT NULL,
    course_code CHAR(12),
    course_name VARCHAR(50) NOT NULL,
    course_description TEXT,
    course_entry_requirements TEXT,
    course_length SMALLINT NOT NULL,
    UNIQUE (course_code)
  );

CREATE TABLE
  room (
    room_id serial PRIMARY KEY NOT NULL,
    building_id INT,
    CONSTRAINT fk_building_id FOREIGN KEY (building_id) REFERENCES building (building_id),
    room_name VARCHAR(100) NOT NULL,
    room_alt_name VARCHAR(100) NOT NULL,
    room_type VARCHAR(100) NOT NULL,
    room_capacity INT NOT NULL
  );

CREATE TABLE
  teacher (
    teacher_id serial PRIMARY KEY NOT NULL,
    staff_id INT,
    CONSTRAINT fk_staff_id FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
    room_id INT,
    CONSTRAINT fk_room_id FOREIGN KEY (room_id) REFERENCES room (room_id),
    teacher_role VARCHAR(50) NOT NULL,
    teacher_tenure VARCHAR(50),
    phone_ext VARCHAR(5) NOT NULL
  );

CREATE TABLE
  teacher_office_hour (
    teacher_id INT NOT NULL,
    hour_id INT NOT NULL,
    PRIMARY KEY (teacher_id, hour_id),
    CONSTRAINT fk_teacher FOREIGN KEY (teacher_id) REFERENCES teacher (teacher_id),
    CONSTRAINT fk_hour FOREIGN KEY (hour_id) REFERENCES office_hour (hour_id)
  );

CREATE TABLE
  room_facility (
    room_id INT NOT NULL,
    facility_id INT NOT NULL,
    PRIMARY KEY (room_id, facility_id),
    CONSTRAINT fk_room FOREIGN KEY (room_id) REFERENCES room (room_id),
    CONSTRAINT fk_facility FOREIGN KEY (facility_id) REFERENCES facility (facility_id),
    quantity INT NOT NULL
  );

CREATE TABLE
  facility (
    facility_id serial PRIMARY KEY NOT NULL,
    facility_total_quantity INT,
    facility_name VARCHAR(100) NOT NULL,
    facility_description TEXT,
    facility_notes TEXT NOT NULL
  );

CREATE TABLE
  office_hour (
    hour_id serial PRIMARY KEY NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    date DATE NOT NULL
  );

CREATE TABLE
  teacher_session (
    teacher_id INT NOT NULL,
    session_id INT NOT NULL,
    PRIMARY KEY (teacher_id, session_id),
    CONSTRAINT fk_teacher FOREIGN KEY (teacher_id) REFERENCES teacher (teacher_id),
    CONSTRAINT fk_session FOREIGN KEY (session_id) REFERENCES session (session_id)
  );

CREATE TABLE
  session (
    session_id serial PRIMARY KEY NOT NULL,
    module_id INT,
    CONSTRAINT fk_module_id FOREIGN KEY (module_id) REFERENCES module (module_id),
    room_id INT,
    CONSTRAINT fk_room_id FOREIGN KEY (room_id) REFERENCES room (room_id),
    session_type ENUM NOT NULL,
    session_start_time VARCHAR(50),
    session_end_time VARCHAR(5) NOT NULL,
    session_date VARCHAR(5) NOT NULL,
    session_feedback TEXT,
    session_mandatory BOOLEAN NOT NULL,
    session_description TEXT
  );

CREATE TABLE
  attendance (
    session_id INT NOT NULL,
    student_id INT NOT NULL,
    PRIMARY KEY (session_id, student_id),
    CONSTRAINT fk_session FOREIGN KEY (session_id) REFERENCES session (session_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES student (student_id),
    attendance_record BOOLEAN NOT NULL
  );

CREATE TABLE
  student_contact (
    contact_id INT NOT NULL,
    student_id INT NOT NULL,
    PRIMARY KEY (contact_id, student_id),
    CONSTRAINT fk_contact FOREIGN KEY (contact_id) REFERENCES emergency_contact (contact_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES student (student_id)
  );

CREATE TABLE
  student (
    student_id SERIAL PRIMARY KEY,
    staff_edu_email CHAR(22),
    student_number CHAR(10) NOT NULL,
    student_fname VARCHAR(50) NOT NULL,
    student_mname VARCHAR(50),
    student_lname VARCHAR(50) NOT NULL,
    student_pronouns VARCHAR(20),
    student_addr1 VARCHAR(30) NOT NULL,
    student_addr2 VARCHAR(30),
    student_city VARCHAR(30) NOT NULL,
    student_postcode VARCHAR(10) NOT NULL,
    student_personal_email VARCHAR(150),
    student_landline VARCHAR(30),
    student_mobile VARCHAR(15) NOT NULL,
    student_dob DATE NOT NULL,
    student_attendance DECIMAL(5, 2) NOT NULL,
    UNIQUE (student_edu_email, student_number)
  );

CREATE TABLE
  student_tuition (
    student_id INT NOT NULL,
    tuition_id INT NOT NULL,
    PRIMARY KEY (student_id, tuition_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES student (student_id),
    CONSTRAINT fk_tuition FOREIGN KEY (tuition_id) REFERENCES tuition (tuition_id)
  );

CREATE TABLE
  tuition (
    tuition_id SERIAL PRIMARY KEY NOT NULL,
    tuition_amount DECIMAL(7, 2) NOT NULL,
    tuition_paid DECIMAL(7, 2) NOT NULL,
    tuition_remaining DECIMAL(7, 2) NOT NULL,
    tuition_remaining_perc DECIMAL(5, 2),
    tuition_deadline DATE NOT NULL
  );

CREATE TABLE
  tuition_payment (
    tuition_payment_id SERIAL PRIMARY KEY NOT NULL,
    tuition_payment_reference CHAR(12) NOT NULL,
    tuition_payment_amount DECIMAL(7, 2) NOT NULL,
    tuition_payment_date DATE NOT NULL,
    tuition_payment_method VARCHAR(50) NOT NULL,
    UNIQUE (tuition_payment_reference)
  );

CREATE TABLE
  student_course (
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    PRIMARY KEY (student_id, course_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES student (student_id),
    CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES course (course_id)
  );

CREATE TABLE
  course_rep (
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    PRIMARY KEY (student_id, course_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES student (student_id),
    CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES course (course_id)
  );

CREATE TABLE
  student_course_progression (
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    PRIMARY KEY (student_id, course_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES student (student_id),
    CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES course (course_id),
    progress_perc DECIMAL(5, 2) NOT NULL,
    feedback TEXT,
    culmative_average DECIMAL(5, 2) NOT NULL
  );

CREATE TABLE
  course_module (
    course_id INT NOT NULL,
    module_id INT NOT NULL,
    PRIMARY KEY (course_id, module_id),
    CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES course (course_id),
    CONSTRAINT fk_module FOREIGN KEY (module_id) REFERENCES module (module_id)
  );

CREATE TABLE
  course_coordinator (
    teacher_id INT NOT NULL,
    course_id INT NOT NULL,
    PRIMARY KEY (teacher_id, course_id),
    CONSTRAINT fk_teacher FOREIGN KEY (teacher_id) REFERENCES teacher (teacher_id),
    CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES course (course_id)
  );

CREATE TABLE
  module_coordinatior (
    teacher_id INT NOT NULL,
    module_id INT NOT NULL,
    PRIMARY KEY (teacher_id, module_id),
    CONSTRAINT fk_teacher FOREIGN KEY (teacher_id) REFERENCES teacher (teacher_id),
    CONSTRAINT fk_module FOREIGN KEY (module_id) REFERENCES module (module_id)
  );

CREATE TABLE
  student_module_progression (
    student_id INT NOT NULL,
    module_id INT NOT NULL,
    PRIMARY KEY (student_id, module_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES student (student_id),
    CONSTRAINT fk_module FOREIGN KEY (module_id) REFERENCES module (module_id),
    module_grade VARCHAR(50) NOT NULL,
    feedback TEXT,
    passed BOOLEAN NOT NULL
  );

CREATE TABLE
  module (
    module_id SERIAL PRIMARY KEY NOT NULL,
    module_code INT NOT NULL,
    module_name VARCHAR(50) NOT NULL,
    module_description TEXT,
    academ_lvl CHAR(2) NOT NULL,
    module_credits INT NOT NULL,
    module_status VARCHAR(20) NOT NULL,
    last_reviewed DATE NOT NULL,
    notional_hours DECIMAL(5, 2) NOT NULL,
    method_of_delivery ENUM NOT NULL,
    module_duration INT NOT NULL,
    UNIQUE (module_code)
  );

CREATE TABLE
  student_assessment_attempt (
    student_id INT NOT NULL,
    attempt_id INT NOT NULL,
    PRIMARY KEY (student_id, attempt_id),
    CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES student (student_id),
    CONSTRAINT fk_assessment_attempt FOREIGN KEY (attempt_id) REFERENCES assessment_attempt (attempt_id),
    highest_grade DECIMAL(5, 2) NOT NULL,
    feedback TEXT,
    attempts INT
  );

CREATE TABLE
  assessment_attempt (
    attempt_id serial PRIMARY KEY NOT NULL,
    assessment_id INT,
    CONSTRAINT fk_assessment_id FOREIGN KEY (assessment_id) REFERENCES assessment (assessment_id),
    attempt_grade DECIMAL(5, 2) NOT NULL,
    attempt_feedback TEXT,
    attempt_no INT NOT NULL,
    attempt_date DATE NOT NULL,
    attempt_time TIME NOT NULL
  );

CREATE TABLE
  assessment (
    assessment_id serial PRIMARY KEY NOT NULL,
    module_id INT,
    CONSTRAINT fk_module_id FOREIGN KEY (module_id) REFERENCES module (module_id),
    assessment_title VARCHAR(50) NOT NULL,
    assessment_set_date DATE NOT NULL,
    assessment_set_time TIME attempt_no INT NOT NULL,
    assessment_due_date DATE NOT NULL,
    assessment_due_time TIME NOT NULL,
    assessment_description TEXT,
    assessment_type VARCHAR(100) NOT NULL,
    assessment_weighting DECIMAL(5, 2) NOT NULL,
    assessment_attachment TEXT,
    assessment_max_attempts INT NOT NULL,
    assessment_visble BOOLEAN NOT NULL
  );