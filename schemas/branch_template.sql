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
CREATE TRIGGER branch_template_before_staff_insert
BEFORE INSERT ON branch_template.staff
FOR EACH ROW
EXECUTE FUNCTION shared.validate_staff();

-- Trigger to create user after insert on staff
CREATE TRIGGER branch_template_trigger_create_student_user
AFTER INSERT ON branch_template.staff
FOR EACH ROW
EXECUTE FUNCTION shared.create_staff_user();

-- Functional index to enforce case insensitive uniqueness of the staff personal email.
CREATE UNIQUE INDEX branch_template_idx_unique_staff_personal_email ON branch_template.staff (LOWER(staff_personal_email));

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

-- Trigger to grant admin or teaching staff prividges after update or insert on staff_role
CREATE TRIGGER branch_template_trigger_grant_staff_roles
AFTER INSERT OR UPDATE ON branch_template.staff_role
FOR EACH ROW
EXECUTE FUNCTION shared.grant_staff_roles();

-- Trigger to revoke admin or teaching staff prividges after update or delete on staff_role
CREATE TRIGGER branch_template_trigger_revoke_roles
AFTER DELETE OR UPDATE ON branch_template.staff_role
FOR EACH ROW
EXECUTE FUNCTION shared.revoke_staff_roles();

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

-- Optimises performance for attendance calculations and joins on course_id in course-specific views
CREATE INDEX branch_template_idx_course_attendance ON branch_template.course (course_id);

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

-- Speeds up joins involving module_id (especially with student_module and course_module)
CREATE INDEX branch_template_idx_module_id ON branch_template.module (module_id);

-- Improves performance for queries joining on module_id in branch-specific attendance views
CREATE INDEX branch_template_idx_module_attendance ON branch_template.module (module_id);
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

-- Multi-column index to improve performance for queries involving both course_id and module_id, commonly used together in joins
CREATE INDEX branch_template_idx_course_module_combined ON branch_template.course_module (course_id, module_id);

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

-- Trigger to create user after insert on student table
CREATE TRIGGER branch_template_trigger_create_student_user
AFTER INSERT ON branch_template.student
FOR EACH ROW
EXECUTE FUNCTION shared.create_student_user();

-- Functional index to enforce case insensitive uniqueness of the student personal email.
CREATE UNIQUE INDEX branch_template_idx_unique_student_personal_email ON branch_template.student (LOWER(student_personal_email));

-- Improves performance for joins or lookups on student_id
CREATE INDEX branch_template_idx_student_id ON branch_template.student (student_id);

-- Index to optimise for queries calculating averages or grouping based on student attendance
CREATE INDEX branch_template_idx_student_attendance ON branch_template.student (student_attendance);

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

-- Multi-column index to improve performance for joins or queries on both student_id and module_id
CREATE INDEX branch_template_idx_student_module_combined ON branch_template.student_module (student_id, module_id);

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

-- Composite index which for queries that filter sessions based on date and start time
CREATE INDEX branch_template_idx_session_date_time ON branch_template.session (session_date, session_start_time);

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

-- Speeds up joins between student_session and session tables, as session_id is frequently used.
CREATE INDEX branch_template_idx_student_session_id ON branch_template.student_session (session_id);

-- Improves performance when filtering on attendance_record
CREATE INDEX branch_template_idx_attendance_record ON branch_template.student_session (attendance_record);

-- Partial index where queries where only records with attendance_record = TRUE
CREATE INDEX branch_template_idx_attendance_record_true ON branch_template.student_session (session_id, student_id) WHERE attendance_record = TRUE;

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

/* GRANT BRANCH SPECIFIC ACCESS */
-- Grant SELECT access to all tables in the branch_template schema except the excluded tables
GRANT SELECT ON ALL TABLES IN SCHEMA branch_template TO student_role;
REVOKE SELECT ON branch_template.staff,
                 branch_template.staff_role,
                 branch_template.staff_department,
                 branch_template.staff_session,
                 branch_template.staff_contact,
                 branch_template.student_contact,
                 branch_template.assignment,
                 branch_template.staff_assignment
FROM student_role;

-- Grant SELECT access to specific tables in the branch_template schema
GRANT SELECT ON branch_template.staff,
                branch_template.staff_role,
                branch_template.staff_department,
                branch_template.assignment,
                branch_template.staff_assignment,
                branch_template.room,
                branch_template.building,
                branch_template.room_facility
TO staff_role;

-- Grant SELECT and UPDATE access to specific tables in branch_template schema
GRANT SELECT, UPDATE ON branch_template.staff_session,
                         branch_template.session,
                         branch_template.student_assessment,
                         branch_template.student_module,
                         branch_template.student_course,
                         branch_template.assessment
TO teaching_staff_role;

-- Grant SELECT access to branch_template.course, branch_template.department_course,
-- branch_template.module, branch_template.course_module
GRANT SELECT ON branch_template.course,
                branch_template.department_course,
                branch_template.module,
                branch_template.course_module
TO teaching_staff_role;

-- Grant SELECT, UPDATE, CREATE, DELETE access to all tables in all schemas
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA branch_template TO admin_staff_role;

/* BRANCH SPECIFIC RLS POLICIES ON SHARED TABLES */
CREATE POLICY branch_template_student_access_policy_shared_assessment
ON shared.assessment
FOR SELECT
USING (
  module_id IN (
    SELECT module_id 
    FROM branch_template.student_module 
    WHERE student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
  AND assessment_visble = TRUE
);

/* BRANCH SPECIFIC RLS POLICIES ON BRANCH TABLES */
-- Staff Policy
ALTER TABLE branch_template.staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_access_policy
ON branch_template.staff
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
  AND staff_id = CURRENT_USER 
);

-- Staff Role Policy
ALTER TABLE branch_template.staff_role ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_role_access_policy
ON branch_template.staff_role
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
  AND staff_id = CURRENT_USER 
);

-- Course Policy
ALTER TABLE branch_template.course ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_teaching_course_access_policy
ON branch_template.course
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

CREATE POLICY branch_template_student_course_access_policy
ON branch_template.course
FOR SELECT
USING (
  course_id IN (
    SELECT course_id
    FROM branch_template.student_course 
    WHERE student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Department Course Policy
ALTER TABLE branch_template.department_course ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_teaching_department_course_access_policy
ON branch_template.course
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

CREATE POLICY branch_template_student_department_course_access_policy
ON branch_template.department_course
FOR SELECT
USING (
  course_id IN (
    SELECT course_id
    FROM branch_template.student_course 
    WHERE student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Module Policy
ALTER TABLE branch_template.module ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_teaching_module_access_policy
ON branch_template.module
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

CREATE POLICY branch_template_student_module_access_policy
ON branch_template.module
FOR SELECT
USING (
  module IN (
    SELECT module_id
    FROM branch_template.module
    WHERE student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Course Module Policy
ALTER TABLE branch_template.course_module ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_teaching_course_module_access_policy
ON branch_template.course_module
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

CREATE POLICY branch_template_student_course_module_access_policy
ON branch_template.course_module
FOR SELECT
USING (
  module IN (
    SELECT module_id
    FROM branch_template.course_module
    WHERE student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Student Policy
ALTER TABLE branch_template.student ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_student_access_policy
ON branch_template.student
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
  AND student_id = CURRENT_USER 
);

-- Student Course Policy
ALTER TABLE branch_template.student_course ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_student_course_access_policy
ON branch_template.student_course
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
  AND student_id = CURRENT_USER 
);

CREATE POLICY branch_template_staff_teaching_student_course_access_policy
ON branch_template.student_course
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

-- Student Module Policy
ALTER TABLE branch_template.student_module ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_student_module_access_policy
ON branch_template.student_module
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
  AND student_id = CURRENT_USER 
);

CREATE POLICY branch_template_staff_teaching_student_module_access_policy
ON branch_template.student_module
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

-- Assessment Policy
ALTER TABLE branch_template.assessment ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_teaching_assessment_access_policy
ON branch_template.assessment
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

CREATE POLICY branch_template_assessment_access_policy_student
ON branch_template.assessment
FOR SELECT
USING (
  assessment_id IN (
    SELECT assessment_id
    FROM branch_template.student_assessment
    WHERE student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Student Assessment Policy
ALTER TABLE branch_template.student_assessment ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_student_assessment_access_policy
ON branch_template.student_assessment
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
  AND student_id = CURRENT_USER 
);

CREATE POLICY branch_template_staff_teaching_student_assessment_access_policy
ON branch_template.student_assessment
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

-- Tuition Policy
ALTER TABLE branch_template.tuition ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_tuition_access_policy
ON branch_template.tuition
FOR SELECT
USING (
  tuition_id IN (
    SELECT t.tuition_id
    FROM 
      branch_template.student_tuition AS st
      JOIN branch_template.tuition AS t USING (tuition_id)
    WHERE st.student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE')
);

-- Student Tuition Policy
ALTER TABLE branch_template.student_tuition ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_student_tuition_access_policy
ON branch_template.student_tuition
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
  AND student_id = CURRENT_USER 
);

-- Tuition Payment Policy
ALTER TABLE branch_template.tuition_payment ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_tuition_payment_access_policy
ON branch_template.tuition_payment
FOR SELECT
USING (
  tuition_payment_id IN (
    SELECT tp.tuition_payment_id
    FROM 
      branch_template.student_tuition AS st
      JOIN branch_template.tuition AS t USING (tuition_id)
      JOIN branch_template.tuition_payment AS tp USING (tuition_id)
    WHERE st.student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE')
);

-- Staff Department Policy
ALTER TABLE branch_template.staff_department ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_department_access_policy
ON branch_template.staff_department
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
  AND staff_id = CURRENT_USER 
);

-- Building Policy
ALTER TABLE branch_template.building ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_building_access_policy
ON branch_template.building
FOR ALL
USING (
  pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
  OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Room Policy
ALTER TABLE branch_template.room ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_room_access_policy
ON branch_template.room
FOR ALL
USING (
  pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
  OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Room Facility Policy
ALTER TABLE branch_template.room_facility ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_room_facility_access_policy
ON branch_template.room_facility
FOR ALL
USING pg_has_role(CURRENT_USER, 'staff_role', 'USAGE');

-- Session Policy
ALTER TABLE branch_template.session ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_session_access_policy_staff
ON branch_template.session
FOR SELECT
USING (
  session_id IN (
    SELECT session_id
    FROM branch_template.staff_session
    WHERE staff_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE')
);

CREATE POLICY branch_template_session_access_policy_student
ON branch_template.session
FOR SELECT
USING (
  session_id IN (
    SELECT session_id
    FROM branch_template.student_session
    WHERE student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Staff Session Policy
ALTER TABLE branch_template.staff_session ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_session_access_policy
ON branch_template.staff_session
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE')
  AND staff_id = CURRENT_USER 
);

-- Student Session Policy
ALTER TABLE branch_template.student_session ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_student_session_access_policy
ON branch_template.student_session
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
  AND student_id = CURRENT_USER 
);

CREATE POLICY branch_template_staff_teaching_student_session_access_policy
ON branch_template.student_session
FOR ALL
USING pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE');

-- Staff Contact Policy
ALTER TABLE branch_template.staff_contact ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_contact_access_policy
ON branch_template.staff_contact
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
  AND staff_id = CURRENT_USER 
);

-- Staff Office Policy
ALTER TABLE branch_template.staff_office ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_office_access_policy
ON branch_template.staff_office
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
  AND staff_id = CURRENT_USER 
);

-- Assignment Policy
ALTER TABLE branch_template.assignment ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_assignment_access_policy
ON branch_template.assignment
FOR SELECT
USING (
  assignment_id IN (
    SELECT assignment_id 
    FROM branch_template.staff_assignment
    WHERE staff_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
);

-- Staff Assignment Module Policy
ALTER TABLE branch_template.staff_assignment ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_assignment_access_policy
ON branch_template.staff_assignment
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'staff_role', 'USAGE')
  AND staff_id = CURRENT_USER 
);
