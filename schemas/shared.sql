/* CREATE SHARED SCHEMA */
CREATE SCHEMA shared;

/* CREATE SHARED FUNCTIONS */

-- Function to validate staff_id, staff_company_email, staff_personal_email
CREATE OR REPLACE FUNCTION shared.validate_staff()
RETURNS TRIGGER AS $$
BEGIN
  NEW.staff_company_email := CONCAT(NEW.staff_id, '@ses.edu.org');

  IF NEW.staff_personal_email IS NOT NULL THEN 
    NEW.staff_personal_email := LOWER(NEW.staff_personal_email);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;  

-- Function to dynamically create schema
CREATE OR REPLACE FUNCTION shared.create_schema(schema_name TEXT)
RETURNS void AS $$
BEGIN
	EXECUTE format('
	CREATE SCHEMA IF NOT EXISTS %I;'
	, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.link_module_assessment()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  RAISE NOTICE ''INSERTING INTO assessment'';
	  INSERT INTO %I.assessment (assessment_id, assessment_set_date, assessment_due_date, assessment_set_time, assessment_due_time, assessment_visble)
	  SELECT
	    sa.assessment_id,
	    ''2024-12-12'',               
	    ''2025-01-12'',               
	    ''00:00'',                 
	    ''23:59'',                 
	    TRUE                        
	  FROM shared.assessment AS sa
	  WHERE sa.module_id = NEW.module_id;
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.link_students_to_assessment()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  RAISE NOTICE ''INSERTING INTO student_assessment'';
	  INSERT INTO %I.student_assessment (student_id, assessment_id, grade)
	  SELECT 
	    NEW.student_id, 
	    a.assessment_id,
	    0.00
	  FROM shared.assessment AS a
	  WHERE a.module_id = NEW.module_id;
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.update_tuition_after_payment() RETURNS TRIGGER AS $inner$ BEGIN
	  UPDATE
	    %I.tuition AS t
	  SET
	    tuition_paid = tuition_paid + tp.tuition_payment_amount,
	    tuition_remaining = tuition_remaining - tp.tuition_payment_amount,
	    tuition_remaining_perc = (
	      (
	        tuition_amount - (tuition_paid + tp.tuition_payment_amount)
	      ) / tuition_amount
	    ) * 100
	  FROM
	    %I.tuition_payment AS tp
	  WHERE
	    tp.tuition_payment_id = NEW.tuition_payment_id
	    AND t.tuition_id = NEW.tuition_id;
	RETURN NULL;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.link_students_to_session()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  RAISE NOTICE ''INSERTING INTO student_session'';
	  INSERT INTO %I.student_session (student_id, session_id, attendance_record)
	  SELECT 
	    sm.student_id, 
	    NEW.session_id, 
	    FALSE
	  FROM %I.student_module AS sm
	  WHERE sm.module_id = NEW.module_id;
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.link_students_to_module()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  RAISE NOTICE ''INSERTING INTO student_module'';
	  INSERT INTO %I.student_module (student_id, module_id, module_grade, passed)
	  SELECT 
	    NEW.student_id, 
	    cm.module_id,
	    0.00,
	    FALSE
	  FROM %I.course_module AS cm
	  WHERE cm.course_id = NEW.course_id; 
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.update_module_grade()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  UPDATE %I.student_module
	  SET 
	    module_grade = (
	      SELECT ROUND(COALESCE(SUM(sa.grade * (a.assessment_weighting / 100)), 0), 2)
	      FROM %I.student_assessment AS sa
	      JOIN shared.assessment AS a ON sa.assessment_id = a.assessment_id
	      WHERE sa.student_id = NEW.student_id AND a.module_id = %I.student_module.module_id
	    ),
	    passed = (
	      SELECT CASE
	        WHEN COALESCE(SUM(sa.grade * (a.assessment_weighting / 100)), 0) >= 40 THEN TRUE
	        ELSE FALSE
	      END
	      FROM %I.student_assessment AS sa
	      JOIN shared.assessment AS a ON sa.assessment_id = a.assessment_id
	      WHERE sa.student_id = NEW.student_id AND a.module_id = %I.student_module.module_id
	    )
	  WHERE student_id = NEW.student_id
	    AND module_id = (
	      SELECT module_id
	      FROM shared.assessment
	      WHERE assessment_id = NEW.assessment_id
	    );
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.update_course_grade()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  UPDATE %I.student_course
	  SET 
	    culmative_average = (
	      SELECT ROUND(COALESCE(AVG(sm.module_grade), 0), 2)
	      FROM %I.student_module AS sm
	      JOIN %I.course_module AS cm ON sm.module_id = cm.module_id
	      WHERE sm.student_id = NEW.student_id AND cm.course_id = %I.student_course.course_id
	    )
	  WHERE student_id = NEW.student_id
	    AND course_id = (
	      SELECT course_id
	      FROM %I.course_module
	      WHERE module_id = NEW.module_id
	    );
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.update_student_attendance()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  UPDATE %I.student
	  SET student_attendance = (
	    SELECT ROUND(CAST(SUM(
	      CASE 
	        WHEN ss.attendance_record THEN 1 
	        ELSE 0 
	      END
	    ) AS NUMERIC) * 100.0 / NULLIF(COUNT(*), 0), 2)
	      FROM %I.student_session AS ss
	      JOIN %I.session AS s ON ss.session_id = s.session_id
	    WHERE ss.student_id = NEW.student_id
	      AND (s.session_date < CURRENT_DATE OR (s.session_date = CURRENT_DATE AND s.session_start_time <= CURRENT_TIME))
	  )
	  WHERE student_id = NEW.student_id;
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.staff (
	  staff_id CHAR(10) DEFAULT (
	    CONCAT(''s'', to_char(nextval(''shared.staff_id_seq''), ''FM000000000''))
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
	);'
	, schema_name);

	EXECUTE format('
	CREATE TRIGGER before_staff_insert
	BEFORE INSERT ON %I.staff
	FOR EACH ROW
	EXECUTE FUNCTION shared.validate_staff();'
	, schema_name);

	EXECUTE format('
	CREATE UNIQUE INDEX %I_unique_staff_personal_email_idx ON %I.staff (LOWER(staff_personal_email));'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.staff_role (
	  staff_id CHAR(10) NOT NULL,
	  role_id INT NOT NULL,
	  PRIMARY KEY (staff_id, role_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id),
	  FOREIGN KEY (role_id) REFERENCES shared.role (role_id)
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.department (
	  dep_id CHAR(7) NOT NULL,
	  staff_id CHAR(10) NOT NULL,
	  PRIMARY KEY (dep_id),
	  FOREIGN KEY (dep_id) REFERENCES shared.department (dep_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id)
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.course (
	  course_id CHAR(7) NOT NULL,
	  staff_id CHAR(10) NOT NULL,
	  PRIMARY KEY (course_id),
	  FOREIGN KEY (course_id) REFERENCES shared.course (course_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id)
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.department_course (
	  dep_id CHAR(7) NOT NULL,
	  course_id CHAR(7) NOT NULL,
	  PRIMARY KEY (dep_id, course_id),
	  FOREIGN KEY (dep_id) REFERENCES %I.department (dep_id),
	  FOREIGN KEY (course_id) REFERENCES %I.course (course_id)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.module (
	  module_id CHAR(7) NOT NULL,
	  PRIMARY KEY (module_id),
	  FOREIGN KEY (module_id) REFERENCES shared.module (module_id)
	);'
	, schema_name);

	EXECUTE format('
	CREATE TABLE %I.course_module (
	  module_id CHAR(7) NOT NULL,
	  course_id CHAR(7) NOT NULL,
	  PRIMARY KEY (module_id, course_id),
	  FOREIGN KEY (module_id) REFERENCES %I.module (module_id),
	  FOREIGN KEY (course_id) REFERENCES %I.course (course_id)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.student (
	  student_id CHAR(10) DEFAULT (
	    CONCAT(''sn'', to_char(nextval(''shared.student_id_seq''), ''FM00000000''))
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
	);'
	, schema_name);

	EXECUTE format('
	CREATE UNIQUE INDEX %I_unique_student_personal_email_idx ON %I.student (LOWER(student_personal_email));'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.student_course (
	  student_id CHAR(10) NOT NULL,
	  course_id CHAR(7) NOT NULL,
	  feedback TEXT,
	  culmative_average DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
	  course_rep BOOLEAN DEFAULT (FALSE) NOT NULL,
	  PRIMARY KEY (student_id, course_id),
	  FOREIGN KEY (student_id) REFERENCES %I.student (student_id),
	  FOREIGN KEY (course_id) REFERENCES %I.course (course_id),
	  CONSTRAINT valid_average_percentage CHECK (culmative_average >= 0 AND culmative_average <= 100)
	);
	 
	CREATE TRIGGER %I_after_insert_student_course
	AFTER INSERT ON %I.student_course
	FOR EACH ROW
	EXECUTE FUNCTION %I.link_students_to_module();'
	, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.student_module (
	  student_id CHAR(10) NOT NULL,
	  module_id CHAR(7) NOT NULL,
	  module_grade DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
	  feedback TEXT,
	  passed BOOLEAN DEFAULT (FALSE) NOT NULL,
	  PRIMARY KEY (student_id, module_id),
	  FOREIGN KEY (student_id) REFERENCES %I.student (student_id),
	  FOREIGN KEY (module_id) REFERENCES %I.module (module_id),
	  CONSTRAINT valid_grade_percentage CHECK (module_grade >= 0 AND module_grade <= 100),
	  CONSTRAINT valid_passed CHECK ((passed = TRUE AND module_grade >= 40) OR (passed = FALSE AND module_grade < 40))
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_after_insert_assessment
	AFTER INSERT ON %I.student_module
	FOR EACH ROW
	EXECUTE FUNCTION %I.link_students_to_assessment();'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_student_assessment_update
	AFTER UPDATE ON %I.student_module
	FOR EACH ROW
	EXECUTE FUNCTION %I.update_course_grade();'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.assessment (
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
	);'
	, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_after_insert_module
	AFTER INSERT ON %I.module
	FOR EACH ROW
	EXECUTE FUNCTION %I.link_module_assessment();'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.student_assessment (
	  student_id CHAR(10) NOT NULL,
	  assessment_id CHAR(10) NOT NULL,
	  grade DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
	  feedback TEXT,
	  PRIMARY KEY (student_id, assessment_id),
	  FOREIGN KEY (student_id) REFERENCES %I.student (student_id),
	  FOREIGN KEY (assessment_id) REFERENCES %I.assessment (assessment_id),
	  CONSTRAINT valid_grade_percentage CHECK (grade >= 0 AND grade <= 100)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_student_assessment_update
	AFTER UPDATE ON %I.student_assessment
	FOR EACH ROW
	EXECUTE FUNCTION %I.update_module_grade();'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.tuition (
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
	);'
	, schema_name);

	EXECUTE format('
	CREATE TABLE %I.student_tuition (
	  student_id CHAR(10) NOT NULL,
	  tuition_id INT NOT NULL,
	  PRIMARY KEY (student_id, tuition_id),
	  FOREIGN KEY (student_id) REFERENCES %I.student (student_id),
	  FOREIGN KEY (tuition_id) REFERENCES %I.tuition (tuition_id)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.tuition_payment (
	  tuition_payment_id SERIAL PRIMARY KEY,
	  tuition_payment_reference CHAR(12) DEFAULT (
	    CONCAT(''py'', to_char(nextval(''shared.tuition_payment_reference_seq''), ''FM0000000000''))
	  ) NOT NULL UNIQUE, 
	  tuition_id INT,
	  tuition_payment_amount DECIMAL(7, 2) NOT NULL,
	  tuition_payment_date DATE NOT NULL,
	  tuition_payment_method shared.payment_method_enum NOT NULL,
	  FOREIGN KEY (tuition_id) REFERENCES %I.tuition(tuition_id)
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TRIGGER after_student_payment_insert 
	AFTER INSERT ON %I.tuition_payment 
	FOR EACH ROW 
	EXECUTE FUNCTION %I.update_tuition_after_payment();'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.staff_department (
	  staff_id CHAR(10) NOT NULL,
	  dep_id CHAR(7) NOT NULL,
	  date_assinged DATE NOT NULL,
	  PRIMARY KEY (staff_id, dep_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id),
	  FOREIGN KEY (dep_id) REFERENCES %I.department (dep_id)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.building (
	  building_id SERIAL PRIMARY KEY,
	  building_name VARCHAR(100) NOT NULL,
	  building_alt_name VARCHAR(100),
	  building_type shared.dep_type_enum NOT NULL,
	  building_addr1 VARCHAR(50) NOT NULL,
	  building_addr2 VARCHAR(50),
	  building_city VARCHAR(50) NOT NULL,
	  building_postcode VARCHAR(10) NOT NULL,
	  building_country VARCHAR(50) NOT NULL
	);'
	, schema_name);

	EXECUTE format('
	CREATE TABLE %I.room (
	  room_id SERIAL PRIMARY KEY,
	  building_id INT NOT NULL,
	  room_type_id INT NOT NULL,
	  room_name VARCHAR(100) NOT NULL,
	  room_alt_name VARCHAR(100) NOT NULL,
	  room_capacity INT NOT NULL,
	  room_floor INT NOT NULL,
	  FOREIGN KEY (building_id) REFERENCES %I.building (building_id),
	  FOREIGN KEY (room_type_id) REFERENCES shared.room_type (room_type_id),
	  CONSTRAINT valid_capacity CHECK (room_capacity >= 0)
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.room_facility (
	  room_id INT NOT NULL,
	  facility_id INT NOT NULL,
	  quantity INT NOT NULL,
	  PRIMARY KEY (room_id, facility_id),
	  FOREIGN KEY (room_id) REFERENCES %I.room (room_id),
	  FOREIGN KEY (facility_id) REFERENCES shared.facility (facility_id),
	  CONSTRAINT valid_quantity CHECK (quantity >= 0)
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.session (
	  session_id CHAR(10) DEFAULT (
	    CONCAT(''sesh'', to_char(nextval(''shared.session_id_seq''), ''FM000000''))
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
	  FOREIGN KEY (room_id) REFERENCES %I.room (room_id),
	  FOREIGN KEY (module_id) REFERENCES %I.module (module_id),
	  CONSTRAINT valid_date_range CHECK (session_start_time < session_end_time)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.staff_session (
	  staff_id CHAR(10) NOT NULL,
	  session_id CHAR(10) NOT NULL,
	  PRIMARY KEY (staff_id, session_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id),
	  FOREIGN KEY (session_id) REFERENCES %I.session (session_id)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.student_session (
	  session_id CHAR(10) NOT NULL,
	  student_id CHAR(10) NOT NULL,
	  attendance_record BOOLEAN NOT NULL,
	  PRIMARY KEY (session_id, student_id),
	  FOREIGN KEY (session_id) REFERENCES %I.session (session_id),
	  FOREIGN KEY (student_id) REFERENCES %I.student (student_id)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_after_insert_session_trigger
	AFTER INSERT ON %I.session
	FOR EACH ROW
	EXECUTE FUNCTION %I.link_students_to_session();'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_update_student_attendance_trigger
	AFTER UPDATE ON %I.student_session
	FOR EACH ROW
	EXECUTE FUNCTION %I.update_student_attendance();'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.staff_contact (
	  contact_id INT NOT NULL,
	  staff_id CHAR(10) NOT NULL,
	  PRIMARY KEY (contact_id, staff_id),
	  FOREIGN KEY (contact_id) REFERENCES shared.emergency_contact (contact_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id)
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.student_contact (
	  contact_id INT NOT NULL,
	  student_id CHAR(10) NOT NULL,
	  PRIMARY KEY (contact_id, student_id),
	  FOREIGN KEY (contact_id) REFERENCES shared.emergency_contact (contact_id),
	  FOREIGN KEY (student_id) REFERENCES %I.student (student_id)
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.staff_office (
	  room_id INT NOT NULL,
	  staff_id CHAR(10) NOT NULL,
	  PRIMARY KEY (room_id, staff_id),
	  FOREIGN KEY (room_id) REFERENCES %I.room (room_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id)
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE TABLE %I.assignment (
	  assignment_id SERIAL PRIMARY KEY,
	  assignment_details TEXT NOT NULL
	);'
	, schema_name);

	EXECUTE format('
	CREATE TABLE %I.staff_assignment (
	  staff_id CHAR(10) NOT NULL,
	  assignment_id INT NOT NULL,
	  PRIMARY KEY (staff_id, assignment_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id),
	  FOREIGN KEY (assignment_id) REFERENCES %I.assignment (assignment_id)
	);'
	, schema_name, schema_name, schema_name);
END; 
$$ LANGUAGE plpgsql;

-- Trigger function to execute create_schema with schema_name ('branch_' + branch_id) after insert on branch
CREATE OR REPLACE FUNCTION shared.after_insert_create_schema()
RETURNS trigger AS $$
BEGIN
  PERFORM shared.create_schema('branch_' || NEW.branch_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/* CREATE SHARED ENUM TYPES */
CREATE TYPE shared.branch_status_enum AS ENUM ('Closed', 'Open');
CREATE TYPE shared.dep_type_enum AS ENUM ('Educational', 'Administrative', 'Operational', 'Maintenance');
CREATE TYPE shared.assessment_type_enum AS ENUM ('Exam', 'Coursework', 'Essay', 'Presentation');
CREATE TYPE shared.title_enum AS ENUM ('Mr', 'Mrs', 'Ms', 'Dr');
CREATE TYPE shared.payment_method_enum AS ENUM ('Credit Card', 'Debit Card', 'Direct Debit', 'Bank Transfer');
CREATE TYPE shared.session_type_enum AS ENUM ('Lecture', 'Practical');
CREATE TYPE shared.academ_lvl_enum AS ENUM ('L4', 'L5', 'L6', 'L7', 'L8');

/* CREATE SHARED SEQUENCES */
CREATE SEQUENCE shared.session_id_seq;
CREATE SEQUENCE shared.tuition_payment_reference_seq;
CREATE SEQUENCE shared.student_id_seq;
CREATE SEQUENCE shared.staff_id_seq;

/* CREATE SHARED TABLES */

-- --------------------------
-- Table structure for BRANCH
-- --------------------------
CREATE SEQUENCE shared.branch_id_seq;

CREATE TABLE shared.branch (
  branch_id CHAR(3) DEFAULT (
    CONCAT('b', to_char(nextval('shared.branch_id_seq'), 'FM00'))
  ) PRIMARY KEY,
  branch_name VARCHAR(50) NOT NULL,
  branch_status shared.branch_status_enum NOT NULL,
  branch_addr1 VARCHAR(150),
  branch_addr2 VARCHAR(150),
  branch_postcode VARCHAR(10),
  branch_contact_number VARCHAR(15),
  branch_email VARCHAR(150) NOT NULL
);

-- Trigger to create_schema after insert on branch
CREATE TRIGGER trigger_create_schema
AFTER INSERT ON shared.branch
FOR EACH ROW
EXECUTE FUNCTION shared.after_insert_create_schema();

-- ------------------------------
-- Table structure for DEPARTMENT
-- ------------------------------
CREATE SEQUENCE shared.dep_id_seq;

CREATE TABLE shared.department (
  dep_id char(7) DEFAULT (
    CONCAT('d', to_char(nextval('shared.dep_id_seq'), 'FM000000'))
  ) PRIMARY KEY,
  dep_name VARCHAR(50) NOT NULL,
  dep_type shared.dep_type_enum NOT NULL,
  dep_description VARCHAR(200)
);

-- --------------------------
-- Table structure for COURSE
-- --------------------------
CREATE SEQUENCE shared.course_id_seq;

CREATE TABLE shared.course (
  course_id CHAR(7) DEFAULT (
    CONCAT('c', to_char(nextval('shared.course_id_seq'), 'FM000000'))
  ) PRIMARY KEY,
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
CREATE SEQUENCE shared.module_id_seq;

CREATE TABLE shared.module (
  module_id CHAR(7) DEFAULT (
    CONCAT('m', to_char(nextval('shared.module_id_seq'), 'FM000000'))
  ) PRIMARY KEY,
  module_name VARCHAR(50) NOT NULL,
  module_description TEXT,
  academ_lvl shared.academ_lvl_enum NOT NULL,
  module_credits INT NOT NULL,
  module_status VARCHAR(20) NOT NULL,
  last_reviewed DATE NOT NULL,
  notional_hours DECIMAL(5, 2) NOT NULL,
  module_duration INT NOT NULL, 
  CONSTRAINT valid_duration CHECK (module_duration IN (1, 2))
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
CREATE SEQUENCE shared.assessment_id_seq;

CREATE TABLE shared.assessment (
  assessment_id CHAR(10) DEFAULT (
    CONCAT('a', to_char(nextval('shared.assessment_id_seq'), 'FM000000000'))
  ) PRIMARY KEY,
  module_id CHAR(7) NOT NULL,
  assessment_title VARCHAR(50) NOT NULL,
  assessment_description TEXT,
  assessment_type shared.assessment_type_enum NOT NULL,
  assessment_weighting DECIMAL(5, 2) NOT NULL,
  assessment_attachment TEXT,
  FOREIGN KEY (module_id) REFERENCES shared.module (module_id),
  CONSTRAINT valid_weight CHECK (assessment_weighting >= 0 AND assessment_weighting <= 100)
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
  facility_notes TEXT
);

-- -----------------------------
-- Table structure for ROOM_TYPE
-- -----------------------------
CREATE TABLE shared.room_type (
  room_type_id SERIAL PRIMARY KEY,
  type_name VARCHAR(100) NOT NULL,
  type_description TEXT
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