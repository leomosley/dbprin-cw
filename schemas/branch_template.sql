/* CREATE SCHEMA */
CREATE SCHEMA IF NOT EXISTS branch_template;

/* CREATE FUNCTIONS */
-- Function to determine if specific room is free at a specific time and date
CREATE OR REPLACE FUNCTION branch_template.is_room_available(
  p_room_id INT,
  p_requested_time TIME,
  p_requested_date DATE
) 
RETURNS BOOLEAN AS $$
DECLARE
  room_session_count INT;
BEGIN
  IF p_requested_time < '09:00:00'::TIME OR p_requested_time > '18:00:00'::TIME THEN
    RAISE EXCEPTION 'Requested time must be between 09:00 and 18:00';
  END IF;
  IF EXTRACT(DOW FROM p_requested_date) IN (0, 6) THEN  -- 0 = Sunday, 6 = Saturday
    RAISE EXCEPTION 'Requested date cannot be a weekend';
  END IF;
  SELECT COUNT(*)
  INTO room_session_count
  FROM branch_template.session
  WHERE 
    room_id = p_room_id
    AND session_date = p_requested_date
    AND (
      (session_start_time <= p_requested_time AND session_end_time > p_requested_time)  -- requested time overlaps with an ongoing session
      OR
      (session_start_time < (p_requested_time + interval '1 minute') AND session_end_time >= (p_requested_time + interval '1 minute'))  -- requested time overlaps with session start time
    );
  IF room_session_count > 0 THEN
    RETURN FALSE;
  ELSE
    RETURN TRUE;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to find available time slots for a specific room on a specific date
CREATE OR REPLACE FUNCTION branch_template.get_day_available_room_time(
  p_room_id INT,
  p_requested_date DATE
)
RETURNS SETOF TIME AS $$
DECLARE
  time_slot_start TIME := '09:00:00'::TIME;
  time_slot_end TIME := '18:00:00'::TIME;
  slot_interval INTERVAL := '1 hour';
BEGIN
  -- Loop through each time slot from 09:00 to 18:00 in 60-minute intervals
  FOR time_slot_start IN
    SELECT time_slot_start + (i * slot_interval) 
    FROM GENERATE_SERIES(0, (EXTRACT(HOUR FROM time_slot_end - time_slot_start) * 60 / 60) - 1) i
    WHERE time_slot_start + (i * slot_interval) >= '09:00:00' AND time_slot_start + (i * slot_interval) <= '18:00:00'
  LOOP
    -- Use the previously created function to check availability
    IF branch_template.is_room_available(p_room_id, time_slot_start, p_requested_date) THEN
      -- If the room is available, return the time slot
      RETURN QUERY SELECT time_slot_start;
    END IF;
  END LOOP;
  RETURN;
END;
$$ LANGUAGE plpgsql;

/* CREATE TRIGGER FUNCTIONS */

-- Trigger function to seed assessment table after insert into module
CREATE OR REPLACE FUNCTION branch_template.link_module_assessment()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO branch_template.assessment (assessment_id, assessment_set_date, assessment_due_date, assessment_set_time, assessment_due_time, assessment_visible)
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
-- CREATE OR REPLACE FUNCTION branch_template.update_module_grade()
-- RETURNS TRIGGER AS $$
-- BEGIN
--   UPDATE branch_template.student_module
--   SET 
--     module_grade = (
--       SELECT ROUND(COALESCE(SUM(sa.grade * (a.assessment_weighting / 100)), 0), 2)
--       FROM branch_template.student_assessment AS sa
--       JOIN shared.assessment AS a ON sa.assessment_id = a.assessment_id
--       WHERE sa.student_id = NEW.student_id AND a.module_id = branch_template.student_module.module_id
--     ),
--     passed = (
--       SELECT CASE
--         WHEN COALESCE(SUM(sa.grade * (a.assessment_weighting / 100)), 0) >= 40 THEN TRUE
--         ELSE FALSE
--       END
--       FROM branch_template.student_assessment AS sa
--       JOIN shared.assessment AS a ON sa.assessment_id = a.assessment_id
--       WHERE sa.student_id = NEW.student_id AND a.module_id = branch_template.student_module.module_id
--     )
--   WHERE student_id = NEW.student_id
--     AND module_id = (
--       SELECT module_id
--       FROM shared.assessment
--       WHERE assessment_id = NEW.assessment_id
--     );
--   RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

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
  staff_mobile VARCHAR(15) NOT NULL UNIQUE
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
  student_attendance DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
  CONSTRAINT valid_percentage CHECK (student_attendance >= 0 AND student_attendance <= 100)
);

-- Trigger to validate staff emails
CREATE TRIGGER branch_template_before_student_insert
BEFORE INSERT ON branch_template.student
FOR EACH ROW
EXECUTE FUNCTION shared.student_email();

-- Trigger to create user after insert on student table
CREATE TRIGGER branch_template_trigger_create_student_user
AFTER INSERT ON branch_template.student
FOR EACH ROW
EXECUTE FUNCTION shared.create_student_user();

-- Functional index to enforce case insensitive uniqueness of the student personal email
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
  assessment_visible BOOLEAN NOT NULL,
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
-- CREATE TRIGGER branch_template_student_assessment_update
-- AFTER UPDATE ON branch_template.student_assessment
-- FOR EACH ROW
-- EXECUTE FUNCTION branch_template.update_module_grade();

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
  tuition_id INT NOT NULL,
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
  date_assinged DATE NOT NULL DEFAULT CURRENT_DATE,
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
  assignment_details TEXT NOT NULL,
  assignment_start_time TIME NOT NULL,
  assignment_end_time TIME NOT NULL,
  assignment_date DATE NOT NULL,
  CONSTRAINT valid_times CHECK (assignment_start_time < assignment_end_time)
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

/* CREATE BRANCH SPECIFIC VIEWS */

-- View to show each students attendance percentages
CREATE OR REPLACE VIEW branch_template.student_attendance AS 
WITH student_details AS (
  SELECT 
    student_id,
    CONCAT_WS(' ', student_fname, student_lname) AS full_name,
    student_edu_email AS email,
    student_attendance
  FROM branch_template.student
)
SELECT 
  sd.student_id AS "Student ID",
  sd.full_name AS "Student Name",
  sd.email AS "Student Email",
  sd.student_attendance AS "Attendance %",
  CASE 
    WHEN sd.student_attendance > 95 THEN 'Excellent'
    WHEN sd.student_attendance > 90 THEN 'Good'
    WHEN sd.student_attendance > 75 THEN 'Satisfactory'
    WHEN sd.student_attendance > 51 THEN 'Irregular Attendance'
    WHEN sd.student_attendance > 10 THEN 'Severly Absent'
    ELSE 'Persitently Absent'
  END AS "Attendance Rating"
FROM student_details AS sd
ORDER BY "Student ID";

-- View to show the average attendance percentage for each module
CREATE OR REPLACE VIEW branch_template.module_attendance AS 
SELECT
  m.module_id AS "Module ID",
  shm.module_name AS "Module Name",
  STRING_AGG(DISTINCT c.course_id, ', ') AS "Modules Courses",
  ROUND(
    AVG(
      CASE
        WHEN total_students > 0 THEN (attending_students * 100.0) / total_students
        ELSE 0
      END
    ), 2
  ) AS "Module Attendance %"
FROM 
  branch_template.module AS m
  JOIN shared.module AS shm USING (module_id)
  JOIN branch_template.session AS ses USING (module_id)
  LEFT JOIN (
    SELECT
      session_id,
      COUNT(*) AS total_students,
      SUM(CASE WHEN attendance_record THEN 1 ELSE 0 END) AS attending_students
    FROM branch_template.student_session
    GROUP BY session_id
  ) AS ss_stats ON ses.session_id = ss_stats.session_id
  JOIN branch_template.course_module AS cm USING (module_id)
  JOIN shared.course AS c USING (course_id)
WHERE 
  ses.session_date < CURRENT_DATE 
  OR (ses.session_date = CURRENT_DATE AND ses.session_end_time < CURRENT_TIME)
GROUP BY "Module ID", "Module Name";

-- View to show the average attendance percentage of each course
CREATE OR REPLACE VIEW branch_template.course_attendance AS 
SELECT
  c.course_id AS "Course ID",
  shc.course_name AS "Course Name",
  CONCAT_WS(' ', stf.staff_fname, stf.staff_lname) AS "Course Coordinator",
  ROUND(AVG(ma."Module Attendance %"), 2) AS "Course Attendance %"
FROM 
  branch_template.course AS c
  JOIN branch_template.course_module AS cm USING (course_id)
  JOIN branch_template.module_attendance AS ma ON cm.module_id = ma."Module ID"
  JOIN shared.course AS shc USING (course_id)
  JOIN branch_template.staff AS stf USING (staff_id)
GROUP BY "Course ID", "Course Name", "Course Coordinator";

-- View to show the students tuition details
CREATE OR REPLACE VIEW branch_template.unpaid_tuition AS
WITH tuition_summary AS (
  SELECT
    st.student_id,
    STRING_AGG(t.tuition_id::TEXT, ', ') AS tuition_ids,
    SUM(t.tuition_amount) AS total_tuition,
    SUM(t.tuition_paid) AS total_paid,
    SUM(t.tuition_amount) - SUM(t.tuition_paid) AS total_tuition_remaining,
    ROUND(
      100 - ((SUM(t.tuition_paid) / NULLIF(SUM(t.tuition_amount), 0)) * 100),
      2
    ) AS overall_remaining_percentage,
    MIN(t.tuition_deadline) AS closest_tuition_deadline
  FROM
    branch_template.student_tuition AS st
    JOIN branch_template.tuition AS t ON st.tuition_id = t.tuition_id
  WHERE
    t.tuition_deadline < CURRENT_DATE
    AND (t.tuition_amount - t.tuition_paid) > 0
  GROUP BY
    st.student_id
)
SELECT
  ts.student_id AS "Student ID",
  CONCAT_WS(' ', 
    s.student_fname, 
    CONCAT(LEFT(s.student_lname, 1), REPEAT('*', LENGTH(s.student_lname) - 1))
  ) AS "Masked Student Name",
  ts.tuition_ids AS "Tuition IDs",
  ts.total_tuition AS "Total Tuition",
  ts.total_paid AS "Total Paid",
  ts.total_tuition_remaining AS "Total Tuition Remaining",
  ts.overall_remaining_percentage AS "Overall Remaining Percentage %",
  ts.closest_tuition_deadline AS "Closest Tuition Deadline",
  CASE
    WHEN ts.overall_remaining_percentage >= 75 THEN 'Critical'
    WHEN ts.overall_remaining_percentage >= 50 THEN 'Warning'
    ELSE 'Low'
  END AS "Risk Level"
FROM
  tuition_summary AS ts
  JOIN branch_template.student AS s ON ts.student_id = s.student_id
ORDER BY
  ts.total_tuition_remaining DESC,
  ts.closest_tuition_deadline;

-- View to show all upcoming session times and dates for each room in branch
CREATE OR REPLACE VIEW branch_template.room_session_times AS
SELECT 
  r.room_id AS "Room ID",
  r.room_alt_name AS "Room Name",
  rt.type_name AS "Room Type",
  s.session_start_time AS "Session Start Time",
  s.session_end_time AS "Session End Time",
  s.session_date AS "Session Date"
FROM 
  branch_template.session AS s
  JOIN branch_template.room AS r USING (room_id)
  JOIN shared.room_type AS rt USING (room_type_id)
WHERE 
  s.session_date > CURRENT_DATE
  OR (s.session_date = CURRENT_DATE AND s.session_start_time > CURRENT_TIME) 
ORDER BY r.room_id, s.session_date, s.session_start_time;

-- View to show students who are low attendane and lower performance
CREATE OR REPLACE VIEW branch_template.low_performing_students AS
SELECT 
  sa."Student ID",
  sa."Student Name",
  sa."Student Email",
  sa."Attendance %",
  sa."Attendance Rating",
  STRING_AGG(
    CONCAT(c.course_id, ' (', c.culmative_average, '%)'),
    ', '
  ) AS "Courses Failing"
FROM 
  branch_template.student_attendance AS sa
  LEFT JOIN branch_template.student_course AS c ON sa."Student ID" = c.student_id
WHERE 
  sa."Attendance %" < 80
  AND c.culmative_average < 40
GROUP BY   
  sa."Student ID",
  sa."Student Name",
  sa."Student Email",
  sa."Attendance %",
  sa."Attendance Rating";

-- View to link staff members and their sessions
CREATE OR REPLACE VIEW branch_template.get_staff_sessions AS 
SELECT 
  ss.staff_id,
  sn.session_date,
  sn.session_start_time,
  sn.session_end_time
FROM
  branch_template.staff_session AS ss
  JOIN branch_template.session AS sn USING(session_id)
WHERE 
  sn.session_date > CURRENT_DATE
  OR (sn.session_date = CURRENT_DATE AND sn.session_start_time < CURRENT_TIME);

-- View to link staff members and their assignments
CREATE OR REPLACE VIEW branch_template.get_staff_assignments AS 
SELECT 
  sa.staff_id,
  a.assignment_date,
  a.assignment_start_time,
  a.assignment_end_time
FROM
  branch_template.staff_assignment AS sa
  JOIN branch_template.assignment AS a USING(assignment_id)
WHERE 
  a.assignment_date > CURRENT_DATE
  OR (a.assignment_date = CURRENT_DATE AND a.assignment_start_time < CURRENT_TIME);

-- View to to show times when staff members are busy with either a session or assignment
CREATE OR REPLACE VIEW branch_template.staff_busy AS
SELECT 
  ss.staff_id,
  ss.session_date AS busy_date,
  ss.session_start_time AS start_time,
  ss.session_end_time AS end_time
FROM 
  branch_template.get_staff_sessions AS ss
UNION
SELECT 
  sa.staff_id,
  sa.assignment_date AS busy_date,
  sa.assignment_start_time AS start_time,
  sa.assignment_end_time AS end_time
FROM 
  branch_template.get_staff_assignments AS sa;

-- View to show date / times staff are available 
CREATE OR REPLACE VIEW branch_template.staff_availability AS
WITH date_range AS (
  SELECT 
    COALESCE(MIN(busy_date), CURRENT_DATE) AS start_date,
    COALESCE(MAX(busy_date), CURRENT_DATE) AS end_date
  FROM branch_template.staff_busy
),
teaching_staff AS (
  SELECT DISTINCT s.staff_id
  FROM branch_template.staff AS s
  JOIN branch_template.staff_role AS sr ON s.staff_id = sr.staff_id
  JOIN shared.role r ON sr.role_id = r.role_id
  WHERE r.role_name IN ('Lecturer', 'Teaching Assistant')
),
time_slots AS (
  SELECT 
    s.staff_id,
    date_series.date AS available_date,
    (date_series.date + ('09:00:00'::TIME + (slot.hour * INTERVAL '1 hour'))) AS slot_timestamp
  FROM 
    teaching_staff AS s,
    date_range AS dr,
    generate_series(dr.start_date, dr.end_date, '1 day'::interval) AS date_series(date),
    generate_series(0, 9) AS slot(hour)
  WHERE EXTRACT(DOW FROM date_series.date) BETWEEN 1 AND 5
),
available_slots AS (
  SELECT 
    staff_id,
    available_date,
    slot_timestamp,
    NOT EXISTS (
      SELECT 1
      FROM branch_template.staff_busy AS sb
      WHERE sb.staff_id = time_slots.staff_id
        AND sb.busy_date = time_slots.available_date::DATE
        AND sb.start_time::TIME < (time_slots.slot_timestamp + INTERVAL '1 hour')::TIME 
        AND sb.end_time::TIME > time_slots.slot_timestamp::TIME
    ) AS is_available
  FROM time_slots
)
SELECT 
  s.staff_id AS "Staff ID",
  CONCAT_WS(' ', s.staff_title, s.staff_fname, s.staff_lname) AS "Staff Name",
  LEFT(as_grouped.available_date::TEXT, 10) AS "Date",
  STRING_AGG(
    to_char(as_grouped.slot_timestamp, 'HH24:MI'),
    ', ' ORDER BY as_grouped.slot_timestamp
  ) AS "Available Times"
FROM 
  branch_template.staff AS s
  JOIN (
    SELECT 
      staff_id, 
      available_date, 
      slot_timestamp
    FROM available_slots
    WHERE is_available
  ) AS as_grouped ON s.staff_id = as_grouped.staff_id
WHERE 
  as_grouped.available_date > CURRENT_DATE
GROUP BY 
  s.staff_id, 
  s.staff_title, 
  s.staff_fname, 
  s.staff_lname, 
  as_grouped.available_date
ORDER BY 
  s.staff_id, 
  as_grouped.available_date;

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

-- Grant SELECT on branch views for admin staff
GRANT SELECT ON branch_template.student_attendance,
                branch_template.module_attendance,
                branch_template.course_attendance,
                branch_template.unpaid_tuition,
                branch_template.room_session_times,
                branch_template.low_performing_students,
                branch_template.get_staff_sessions,
                branch_template.get_staff_assignments,
                branch_template.staff_busy,
                branch_template.staff_availability
TO admin_staff_role;

-- Grant SELECT on branch views for teaching staff
GRANT SELECT ON branch_template.module_attendance,
                branch_template.course_attendance,
                branch_template.room_session_times,
                branch_template.get_staff_sessions,
                branch_template.get_staff_assignments
TO teaching_staff_role;

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
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

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
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

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
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

CREATE POLICY branch_template_student_module_access_policy
ON branch_template.module
FOR SELECT
USING (
  module_id IN (
    SELECT module_id
    FROM branch_template.student_module
    WHERE student_id = CURRENT_USER
  )
  AND pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
);

-- Course Module Policy
ALTER TABLE branch_template.course_module ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_teaching_course_module_access_policy
ON branch_template.course_module
FOR ALL
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

CREATE POLICY branch_template_student_course_module_access_policy
ON branch_template.course_module
FOR SELECT
USING (
  module_id IN (
    SELECT module_id
    FROM branch_template.student_module
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
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

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
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

-- Assessment Policy
ALTER TABLE branch_template.assessment ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_staff_teaching_assessment_access_policy
ON branch_template.assessment
FOR ALL
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

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
  AND assessment_visible = TRUE
);

-- Student Assessment Policy
ALTER TABLE branch_template.student_assessment ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_template_student_assessment_access_policy
ON branch_template.student_assessment
FOR SELECT
USING (
  pg_has_role(CURRENT_USER, 'student_role', 'USAGE')
  AND student_id = CURRENT_USER 
  AND assessment_id IN (
    SELECT assessment_id
    FROM branch_template.assessment 
    WHERE assessment_visible = TRUE
  )
);

CREATE POLICY branch_template_staff_teaching_student_assessment_access_policy
ON branch_template.student_assessment
FOR ALL
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

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
USING (pg_has_role(CURRENT_USER, 'staff_role', 'USAGE'));

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
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

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