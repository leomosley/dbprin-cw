/* CREATE SCHEMA */
CREATE SCHEMA IF NOT EXISTS branch_template;

/* CREATE TRIGGER FUNCTIONS */

-- Trigger function to seed assessment table after insert into module
CREATE OR REPLACE FUNCTION branch_template.link_module_assessment()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO branch_template.assessment (assessment_id, assessment_set_date, assessment_due_date, assessment_set_time, assessment_due_time, assessment_visble)
  SELECT
    sa.assessment_id,
    '2024-12-12',               
    '2025-01-12',               
    '00:00',                 
    '23:59',                 
    TRUE                        
  FROM shared.assessment AS sa
  WHERE sa.module_id = NEW.module_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to seed student_assessment table after insert into assessment
CREATE OR REPLACE FUNCTION branch_template.link_students_to_assessment()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO branch_template.student_assessment (student_id, assessment_id, grade)
  SELECT 
    NEW.student_id, 
    a.assessment_id,
    0.00
  FROM shared.assessment AS a
  WHERE a.module_id = NEW.module_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to update tuition after insert into tuition_payment
CREATE OR REPLACE FUNCTION branch_template.update_tuition_after_payment() RETURNS TRIGGER AS $$ BEGIN
  UPDATE
    branch_template.tuition AS t
  SET
    tuition_paid = tuition_paid + tp.tuition_payment_amount,
    tuition_remaining = tuition_remaining - tp.tuition_payment_amount,
    tuition_remaining_perc = (
      (
        tuition_amount - (tuition_paid + tp.tuition_payment_amount)
      ) / tuition_amount
    ) * 100
  FROM
    branch_template.tuition_payment AS tp
  WHERE
    tp.tuition_payment_id = NEW.tuition_payment_id
    AND t.tuition_id = NEW.tuition_id;
RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to seed student_session after insert into session
CREATE OR REPLACE FUNCTION branch_template.link_students_to_session()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO branch_template.student_session (student_id, session_id, attendance_record)
  SELECT 
    sm.student_id, 
    NEW.session_id, 
    FALSE
  FROM branch_template.student_module AS sm
  WHERE sm.module_id = NEW.module_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to seed student_module after insert into module
CREATE OR REPLACE FUNCTION branch_template.link_students_to_module()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO branch_template.student_module (student_id, module_id, module_grade, passed)
  SELECT 
    NEW.student_id, 
    cm.module_id,
    0.00,
    FALSE
  FROM branch_template.course_module AS cm
  WHERE cm.course_id = NEW.course_id; 
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to update student_module to calculate their average grade
CREATE OR REPLACE FUNCTION branch_template.update_module_grade()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE branch_template.student_module
  SET 
    module_grade = (
      SELECT ROUND(COALESCE(SUM(sa.grade * (a.assessment_weighting / 100)), 0), 2)
      FROM branch_template.student_assessment AS sa
      JOIN shared.assessment AS a ON sa.assessment_id = a.assessment_id
      WHERE sa.student_id = NEW.student_id AND a.module_id = branch_template.student_module.module_id
    ),
    passed = (
      SELECT CASE
        WHEN COALESCE(SUM(sa.grade * (a.assessment_weighting / 100)), 0) >= 40 THEN TRUE
        ELSE FALSE
      END
      FROM branch_template.student_assessment AS sa
      JOIN shared.assessment AS a ON sa.assessment_id = a.assessment_id
      WHERE sa.student_id = NEW.student_id AND a.module_id = branch_template.student_module.module_id
    )
  WHERE student_id = NEW.student_id
    AND module_id = (
      SELECT module_id
      FROM shared.assessment
      WHERE assessment_id = NEW.assessment_id
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to update student_course to calculate their average grade
CREATE OR REPLACE FUNCTION branch_template.update_course_grade()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE branch_template.student_course
  SET 
    culmative_average = (
      SELECT ROUND(COALESCE(AVG(sm.module_grade), 0), 2)
      FROM branch_template.student_module AS sm
      JOIN branch_template.course_module AS cm ON sm.module_id = cm.module_id
      WHERE sm.student_id = NEW.student_id AND cm.course_id = branch_template.student_course.course_id
    )
  WHERE student_id = NEW.student_id
    AND course_id = (
      SELECT course_id
      FROM branch_template.course_module
      WHERE module_id = NEW.module_id
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to update student attendance after update on student_session
CREATE OR REPLACE FUNCTION branch_template.update_student_attendance()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE branch_template.student
  SET student_attendance = (
    SELECT ROUND(CAST(SUM(
      CASE 
        WHEN ss.attendance_record THEN 1 
        ELSE 0 
      END
    ) AS NUMERIC) * 100.0 / NULLIF(COUNT(*), 0), 2)
      FROM branch_template.student_session AS ss
      JOIN branch_template.session AS s ON ss.session_id = s.session_id
    WHERE ss.student_id = NEW.student_id
      AND (s.session_date < CURRENT_DATE OR (s.session_date = CURRENT_DATE AND s.session_start_time <= CURRENT_TIME))
  )
  WHERE student_id = NEW.student_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/* CREATE TABLES */

-- -------------------------
-- Table structure for STAFF
-- -------------------------
CREATE TABLE branch_template.staff (
  staff_id CHAR(10) DEFAULT (
    CONCAT('s', to_char(nextval('shared.staff_id_seq'), 'FM000000000'))
  ) PRIMARY KEY,
  staff_company_email CHAR(22) UNIQUE,
  staff_personal_email VARCHAR(150) NOT NULL UNIQUE,
  staff_fname VARCHAR(50) NOT NULL,
  staff_mname VARCHAR(50),
  staff_lname VARCHAR(50) NOT NULL,
  staff_title shared.title_enum NOT NULL,
  staff_addr1 VARCHAR(30) NOT NULL,
  staff_addr2 VARCHAR(30),
  staff_city VARCHAR(30) NOT NULL,
  staff_postcode VARCHAR(10) NOT NULL,
  staff_landline VARCHAR(30) NOT NULL,
  staff_mobile VARCHAR(15) NOT NULL UNIQUE,
  staff_dob DATE NOT NULL
);

-- Trigger to validate staff emails
CREATE TRIGGER before_staff_insert
BEFORE INSERT ON branch_template.staff
FOR EACH ROW
EXECUTE FUNCTION shared.validate_staff();

-- Functional index to enforce case insensitive uniqueness of the staff personal email.
CREATE UNIQUE INDEX branch_template_unique_staff_personal_email_idx ON branch_template.staff (LOWER(staff_personal_email));

-- ------------------------------
-- Table structure for STAFF_ROLE
-- ------------------------------
CREATE TABLE branch_template.staff_role (
  staff_id CHAR(10) NOT NULL,
  role_id INT NOT NULL,
  PRIMARY KEY (staff_id, role_id),
  FOREIGN KEY (staff_id) REFERENCES branch_template.staff (staff_id),
  FOREIGN KEY (role_id) REFERENCES shared.role (role_id)
);

-- ------------------------------
-- Table structure for DEPARTMENT
-- ------------------------------
CREATE TABLE branch_template.department (
  dep_id CHAR(7) NOT NULL,
  staff_id CHAR(10) NOT NULL,
  PRIMARY KEY (dep_id),
  FOREIGN KEY (dep_id) REFERENCES shared.department (dep_id),
  FOREIGN KEY (staff_id) REFERENCES branch_template.staff (staff_id)
);

-- --------------------------
-- Table structure for COURSE
-- --------------------------
CREATE TABLE branch_template.course (
  course_id CHAR(7) NOT NULL,
  staff_id CHAR(10) NOT NULL,
  PRIMARY KEY (course_id),
  FOREIGN KEY (course_id) REFERENCES shared.course (course_id),
  FOREIGN KEY (staff_id) REFERENCES branch_template.staff (staff_id)
);

-- -------------------------------------
-- Table structure for DEPARTMENT_COURSE
-- -------------------------------------
CREATE TABLE branch_template.department_course (
  dep_id CHAR(7) NOT NULL,
  course_id CHAR(7) NOT NULL,
  PRIMARY KEY (dep_id, course_id),
  FOREIGN KEY (dep_id) REFERENCES branch_template.department (dep_id),
  FOREIGN KEY (course_id) REFERENCES branch_template.course (course_id)
);

-- --------------------------
-- Table structure for MODULE
-- --------------------------
CREATE TABLE branch_template.module (
  module_id CHAR(7) NOT NULL,
  PRIMARY KEY (module_id),
  FOREIGN KEY (module_id) REFERENCES shared.module (module_id)
);

-- ----------------------------------
-- Table structure for COURSE_MODULE
-- ----------------------------------
CREATE TABLE branch_template.course_module (
  module_id CHAR(7) NOT NULL,
  course_id CHAR(7) NOT NULL,
  PRIMARY KEY (module_id, course_id),
  FOREIGN KEY (module_id) REFERENCES branch_template.module (module_id),
  FOREIGN KEY (course_id) REFERENCES branch_template.course (course_id)
);

-- ---------------------------
-- Table structure for STUDENT
-- ---------------------------
CREATE TABLE branch_template.student (
  student_id CHAR(10) DEFAULT (
    CONCAT('sn', to_char(nextval('shared.student_id_seq'), 'FM00000000'))
  ) PRIMARY KEY,
  student_edu_email CHAR(22) UNIQUE,
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
  student_attendance DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
  CONSTRAINT valid_percentage CHECK (student_attendance >= 0 AND student_attendance <= 100)
);

-- Functional index to enforce case insensitive uniqueness of the student personal email.
CREATE UNIQUE INDEX branch_template_unique_student_personal_email_idx ON branch_template.student (LOWER(student_personal_email));

-- ----------------------------------
-- Table structure for STUDENT_COURSE
-- ----------------------------------
CREATE TABLE branch_template.student_course (
  student_id CHAR(10) NOT NULL,
  course_id CHAR(7) NOT NULL,
  feedback TEXT,
  culmative_average DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
  course_rep BOOLEAN DEFAULT (FALSE) NOT NULL,
  PRIMARY KEY (student_id, course_id),
  FOREIGN KEY (student_id) REFERENCES branch_template.student (student_id),
  FOREIGN KEY (course_id) REFERENCES branch_template.course (course_id),
  CONSTRAINT valid_average_percentage CHECK (culmative_average >= 0 AND culmative_average <= 100)
);
 
-- Trigger to seed student_module based off course_module after insert on student_course 
CREATE TRIGGER branch_template_after_insert_student_course
AFTER INSERT ON branch_template.student_course
FOR EACH ROW
EXECUTE FUNCTION branch_template.link_students_to_module();

-- ----------------------------------
-- Table structure for STUDENT_MODULE
-- ----------------------------------
CREATE TABLE branch_template.student_module (
  student_id CHAR(10) NOT NULL,
  module_id CHAR(7) NOT NULL,
  module_grade DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
  feedback TEXT,
  passed BOOLEAN DEFAULT (FALSE) NOT NULL,
  PRIMARY KEY (student_id, module_id),
  FOREIGN KEY (student_id) REFERENCES branch_template.student (student_id),
  FOREIGN KEY (module_id) REFERENCES branch_template.module (module_id),
  CONSTRAINT valid_grade_percentage CHECK (module_grade >= 0 AND module_grade <= 100),
  CONSTRAINT valid_passed CHECK ((passed = TRUE AND module_grade >= 40) OR (passed = FALSE AND module_grade < 40))
);

-- Trigger to seed student_assessment based of the module they are taking and the assesments it provides (in shared) after insert on student_module
CREATE TRIGGER branch_template_after_insert_assessment
AFTER INSERT ON branch_template.student_module
FOR EACH ROW
EXECUTE FUNCTION branch_template.link_students_to_assessment();

-- Trigger to calcuate their total grade after upadate on student_course 
CREATE TRIGGER branch_template_student_assessment_update
AFTER UPDATE ON branch_template.student_module
FOR EACH ROW
EXECUTE FUNCTION branch_template.update_course_grade();

-- ------------------------------
-- Table structure for ASSESSMENT
-- ------------------------------
CREATE TABLE branch_template.assessment (
  assessment_id CHAR(10) NOT NULL,
  assessment_set_date DATE NOT NULL,
  assessment_due_date DATE NOT NULL,
  assessment_set_time TIME  NOT NULL,
  assessment_due_time TIME NOT NULL,
  assessment_visble BOOLEAN NOT NULL,
  PRIMARY KEY (assessment_id),
  FOREIGN KEY (assessment_id) REFERENCES shared.assessment (assessment_id),
  CONSTRAINT valid_date_range CHECK (assessment_set_date < assessment_due_date OR 
                                     (assessment_set_date = assessment_due_date AND assessment_set_time < assessment_due_time))
);

-- Trigger to seed assessment based off assessments module provides (in shared) after insert on module
CREATE TRIGGER branch_template_after_insert_module
AFTER INSERT ON branch_template.module
FOR EACH ROW
EXECUTE FUNCTION branch_template.link_module_assessment();

-- --------------------------------------
-- Table structure for STUDENT_ASSESSMENT
-- --------------------------------------
CREATE TABLE branch_template.student_assessment (
  student_id CHAR(10) NOT NULL,
  assessment_id CHAR(10) NOT NULL,
  grade DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
  feedback TEXT,
  PRIMARY KEY (student_id, assessment_id),
  FOREIGN KEY (student_id) REFERENCES branch_template.student (student_id),
  FOREIGN KEY (assessment_id) REFERENCES branch_template.assessment (assessment_id),
  CONSTRAINT valid_grade_percentage CHECK (grade >= 0 AND grade <= 100)
);

-- Trigger to calcuate their total grade after upadate on student_module
CREATE TRIGGER branch_template_student_assessment_update
AFTER UPDATE ON branch_template.student_assessment
FOR EACH ROW
EXECUTE FUNCTION branch_template.update_module_grade();

-- ---------------------------
-- Table structure for TUITION
-- ---------------------------
CREATE TABLE branch_template.tuition (
  tuition_id SERIAL PRIMARY KEY,
  tuition_amount DECIMAL(7, 2) NOT NULL,
  tuition_paid DECIMAL(7, 2) DEFAULT (0.00) NOT NULL,
  tuition_remaining DECIMAL(7, 2) NOT NULL,
  tuition_remaining_perc DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
  tuition_deadline DATE NOT NULL,
  CONSTRAINT valid_tuition_amount CHECK (tuition_amount >= 0),
  CONSTRAINT valid_tuition_paid CHECK (tuition_paid >= 0 AND tuition_paid <= tuition_amount),
  CONSTRAINT valid_tuition_remaining CHECK (tuition_remaining >= 0 AND tuition_remaining <= tuition_amount),
  CONSTRAINT valid_tuition_remaining_perc CHECK (tuition_remaining_perc >= 0 AND tuition_remaining_perc <= 100)
);

-- -----------------------------------
-- Table structure for STUDENT_TUITION
-- -----------------------------------
CREATE TABLE branch_template.student_tuition (
  student_id CHAR(10) NOT NULL,
  tuition_id INT NOT NULL,
  PRIMARY KEY (student_id, tuition_id),
  FOREIGN KEY (student_id) REFERENCES branch_template.student (student_id),
  FOREIGN KEY (tuition_id) REFERENCES branch_template.tuition (tuition_id)
);

-- -----------------------------------
-- Table structure for TUITION_PAYMENT
-- -----------------------------------
CREATE TABLE branch_template.tuition_payment (
  tuition_payment_id SERIAL PRIMARY KEY,
  tuition_payment_reference CHAR(12) DEFAULT (
    CONCAT('py', to_char(nextval('shared.tuition_payment_reference_seq'), 'FM0000000000'))
  ) NOT NULL UNIQUE, 
  tuition_id INT,
  tuition_payment_amount DECIMAL(7, 2) NOT NULL,
  tuition_payment_date DATE NOT NULL,
  tuition_payment_method shared.payment_method_enum NOT NULL,
  FOREIGN KEY (tuition_id) REFERENCES branch_template.tuition(tuition_id)
);

-- Trigger to update values in the tuition table after insert on tuition_payment. 
CREATE TRIGGER after_student_payment_insert 
AFTER INSERT ON branch_template.tuition_payment 
FOR EACH ROW 
EXECUTE FUNCTION branch_template.update_tuition_after_payment();

-- ------------------------------------
-- Table structure for STAFF_DEPARTMENT
-- ------------------------------------
CREATE TABLE branch_template.staff_department (
  staff_id CHAR(10) NOT NULL,
  dep_id CHAR(7) NOT NULL,
  date_assinged DATE NOT NULL,
  PRIMARY KEY (staff_id, dep_id),
  FOREIGN KEY (staff_id) REFERENCES branch_template.staff (staff_id),
  FOREIGN KEY (dep_id) REFERENCES branch_template.department (dep_id)
);

-- ----------------------------
-- Table structure for BUILDING
-- ----------------------------
CREATE TABLE branch_template.building (
  building_id SERIAL PRIMARY KEY,
  building_name VARCHAR(100) NOT NULL,
  building_alt_name VARCHAR(100),
  building_type shared.dep_type_enum NOT NULL,
  building_addr1 VARCHAR(50) NOT NULL,
  building_addr2 VARCHAR(50),
  building_city VARCHAR(50) NOT NULL,
  building_postcode VARCHAR(10) NOT NULL,
  building_country VARCHAR(50) NOT NULL
);

-- ------------------------
-- Table structure for ROOM
-- ------------------------
CREATE TABLE branch_template.room (
  room_id SERIAL PRIMARY KEY,
  building_id INT NOT NULL,
  room_type_id INT NOT NULL,
  room_name VARCHAR(100) NOT NULL,
  room_alt_name VARCHAR(100) NOT NULL,
  room_capacity INT NOT NULL,
  room_floor INT NOT NULL,
  FOREIGN KEY (building_id) REFERENCES branch_template.building (building_id),
  FOREIGN KEY (room_type_id) REFERENCES shared.room_type (room_type_id),
  CONSTRAINT valid_capacity CHECK (room_capacity >= 0)
);

-- ---------------------------------
-- Table structure for ROOM_FACILITY
-- ---------------------------------
CREATE TABLE branch_template.room_facility (
  room_id INT NOT NULL,
  facility_id INT NOT NULL,
  quantity INT NOT NULL,
  PRIMARY KEY (room_id, facility_id),
  FOREIGN KEY (room_id) REFERENCES branch_template.room (room_id),
  FOREIGN KEY (facility_id) REFERENCES shared.facility (facility_id),
  CONSTRAINT valid_quantity CHECK (quantity >= 0)
);

-- ---------------------------
-- Table structure for SESSION
-- ---------------------------
CREATE TABLE branch_template.session (
  session_id CHAR(10) DEFAULT (
    CONCAT('sesh', to_char(nextval('shared.session_id_seq'), 'FM000000'))
  ) PRIMARY KEY,
  room_id INT NOT NULL,
  module_id CHAR(7) NOT NULL,
  session_type shared.session_type_enum NOT NULL,
  session_start_time TIME NOT NULL,
  session_end_time TIME NOT NULL,
  session_date DATE NOT NULL,
  session_feedback TEXT,
  session_mandatory BOOLEAN NOT NULL,
  session_description TEXT,
  FOREIGN KEY (room_id) REFERENCES branch_template.room (room_id),
  FOREIGN KEY (module_id) REFERENCES branch_template.module (module_id),
  CONSTRAINT valid_date_range CHECK (session_start_time < session_end_time)
);

-- ---------------------------------
-- Table structure for STAFF_SESSION
-- ---------------------------------
CREATE TABLE branch_template.staff_session (
  staff_id CHAR(10) NOT NULL,
  session_id CHAR(10) NOT NULL,
  PRIMARY KEY (staff_id, session_id),
  FOREIGN KEY (staff_id) REFERENCES branch_template.staff (staff_id),
  FOREIGN KEY (session_id) REFERENCES branch_template.session (session_id)
);

-- -----------------------------------
-- Table structure for STUDENT_SESSION
-- -----------------------------------
CREATE TABLE branch_template.student_session (
  session_id CHAR(10) NOT NULL,
  student_id CHAR(10) NOT NULL,
  attendance_record BOOLEAN NOT NULL,
  PRIMARY KEY (session_id, student_id),
  FOREIGN KEY (session_id) REFERENCES branch_template.session (session_id),
  FOREIGN KEY (student_id) REFERENCES branch_template.student (student_id)
);

-- Trigger to link students to session
CREATE TRIGGER branch_template_after_insert_session_trigger
AFTER INSERT ON branch_template.session
FOR EACH ROW
EXECUTE FUNCTION branch_template.link_students_to_session();

-- Trigger to update student_attendance
CREATE TRIGGER branch_template_update_student_attendance_trigger
AFTER UPDATE ON branch_template.student_session
FOR EACH ROW
EXECUTE FUNCTION branch_template.update_student_attendance();

-- ---------------------------------
-- Table structure for STAFF_CONTACT
-- ---------------------------------
CREATE TABLE branch_template.staff_contact (
  contact_id INT NOT NULL,
  staff_id CHAR(10) NOT NULL,
  PRIMARY KEY (contact_id, staff_id),
  FOREIGN KEY (contact_id) REFERENCES shared.emergency_contact (contact_id),
  FOREIGN KEY (staff_id) REFERENCES branch_template.staff (staff_id)
);

-- -----------------------------------
-- Table structure for STUDENT_CONTACT
-- -----------------------------------
CREATE TABLE branch_template.student_contact (
  contact_id INT NOT NULL,
  student_id CHAR(10) NOT NULL,
  PRIMARY KEY (contact_id, student_id),
  FOREIGN KEY (contact_id) REFERENCES shared.emergency_contact (contact_id),
  FOREIGN KEY (student_id) REFERENCES branch_template.student (student_id)
);

-- --------------------------------
-- Table structure for STAFF_OFFICE
-- --------------------------------
CREATE TABLE branch_template.staff_office (
  room_id INT NOT NULL,
  staff_id CHAR(10) NOT NULL,
  PRIMARY KEY (room_id, staff_id),
  FOREIGN KEY (room_id) REFERENCES branch_template.room (room_id),
  FOREIGN KEY (staff_id) REFERENCES branch_template.staff (staff_id)
);

-- ------------------------------
-- Table structure for ASSIGNMENT
-- ------------------------------
CREATE TABLE branch_template.assignment (
  assignment_id SERIAL PRIMARY KEY,
  assignment_details TEXT NOT NULL
);

-- ------------------------------------
-- Table structure for STAFF_ASSIGNMENT
-- ------------------------------------
CREATE TABLE branch_template.staff_assignment (
  staff_id CHAR(10) NOT NULL,
  assignment_id INT NOT NULL,
  PRIMARY KEY (staff_id, assignment_id),
  FOREIGN KEY (staff_id) REFERENCES branch_template.staff (staff_id),
  FOREIGN KEY (assignment_id) REFERENCES branch_template.assignment (assignment_id)
);
