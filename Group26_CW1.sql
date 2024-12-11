/* CREATE SHARED SCHEMA */
CREATE SCHEMA shared;

/* CREATE SHARED FUNCTIONS */

-- Function to validate staff_id, staff_company_email, staff_personal_email
CREATE OR REPLACE FUNCTION shared.validate_staff()
RETURNS TRIGGER AS $$
BEGIN
  RAISE NOTICE 'VALIDATING STAFF INSERT FOR %', NEW.staff_id;
  NEW.staff_company_email := CONCAT(NEW.staff_id, '@ses.edu.org');

  IF NEW.staff_personal_email IS NOT NULL THEN 
    NEW.staff_personal_email := LOWER(NEW.staff_personal_email);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql; 

-- Trigger function to create users and assign roles after insert on staff
CREATE OR REPLACE FUNCTION shared.create_staff_user() 
RETURNS TRIGGER AS 
$$
BEGIN
  RAISE NOTICE 'CREATE STAFF USER %', NEW.staff_id;
  EXECUTE format('DROP ROLE IF EXISTS %I;', NEW.staff_id);
  EXECUTE format('
  CREATE ROLE %I WITH LOGIN;
  GRANT staff_role TO %I;'
  , NEW.staff_id, NEW.staff_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to create users and assign roles after insert on student
CREATE OR REPLACE FUNCTION shared.create_student_user() 
RETURNS TRIGGER AS 
$$
BEGIN
  RAISE NOTICE 'CREATE STUDENT USER %', NEW.student_id;
  EXECUTE format('DROP ROLE IF EXISTS %I;', NEW.student_id);
  EXECUTE format('
  CREATE ROLE %I WITH LOGIN;
  GRANT student_role TO %I;'
  , NEW.student_id, NEW.student_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to grant admin_staff_role and teachign_staff_role to user after update or insert on staff_role
CREATE OR REPLACE FUNCTION shared.grant_staff_roles() 
RETURNS TRIGGER AS 
$$
BEGIN
  IF NEW.role_id = (SELECT role_id FROM shared.role WHERE role_name = 'Admin staff') THEN
    RAISE NOTICE 'GRANTING ADMIN STAFF PRIVILEGES FOR %', NEW.staff_id;
    EXECUTE format('
    GRANT admin_staff_role TO %I;'
    , NEW.staff_id);
  END IF;
  IF NEW.role_id IN (SELECT role_id FROM shared.role WHERE role_name IN ('Lecturer', 'Teaching Assistant')) THEN
    RAISE NOTICE 'GRANTING TEACHING STAFF PRIVILEGES FOR %', NEW.staff_id;
    EXECUTE format('
    GRANT teaching_staff_role TO %I;'
    , NEW.staff_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to revoke admin_staff_role or teaching_staff_role to user after update or delete on staff_role
CREATE OR REPLACE FUNCTION shared.revoke_staff_roles()
RETURNS TRIGGER AS 
$$
BEGIN
  IF OLD.role_id = (SELECT role_id FROM shared.role WHERE role_name = 'Admin staff') THEN
    RAISE NOTICE 'REVOKING ADMIN STAFF PRIVILEGES FOR %', OLD.staff_id;
    EXECUTE format('
    REVOKE admin_staff_role FROM %I;', 
    OLD.staff_id);
  END IF;
  IF OLD.role_id IN (SELECT role_id FROM shared.role WHERE role_name IN ('Lecturer', 'Teaching Assistant')) THEN
    RAISE NOTICE 'REVOKING TEACHING STAFF PRIVILEGES FOR %', OLD.staff_id;
    EXECUTE format('
    REVOKE teaching_staff_role FROM %I;'
    , OLD.staff_id);
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Function to dynamically create schema
CREATE OR REPLACE FUNCTION shared.create_schema(schema_name TEXT)
RETURNS void AS $$
BEGIN
  RAISE NOTICE 'CREATING SCHEMA %', schema_name;

	EXECUTE format('
	CREATE SCHEMA IF NOT EXISTS %I;'
	, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.link_module_assessment()
	RETURNS TRIGGER AS $inner$
	BEGIN
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
	CREATE TRIGGER %I_before_staff_insert
	BEFORE INSERT ON %I.staff
	FOR EACH ROW
	EXECUTE FUNCTION shared.validate_staff();'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_trigger_create_student_user
	AFTER INSERT ON %I.staff
	FOR EACH ROW
	EXECUTE FUNCTION shared.create_staff_user();'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE UNIQUE INDEX %I_idx_unique_staff_personal_email ON %I.staff (LOWER(staff_personal_email));'
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
	CREATE TRIGGER %I_trigger_grant_staff_roles
	AFTER INSERT OR UPDATE ON %I.staff_role
	FOR EACH ROW
	EXECUTE FUNCTION shared.grant_staff_roles();'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_trigger_revoke_roles
	AFTER DELETE OR UPDATE ON %I.staff_role
	FOR EACH ROW
	EXECUTE FUNCTION shared.revoke_staff_roles();'
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
	CREATE INDEX %I_idx_course_attendance ON %I.course (course_id);'
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
	CREATE INDEX %I_idx_module_id ON %I.module (module_id);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE INDEX %I_idx_module_attendance ON %I.module (module_id);
	CREATE TABLE %I.course_module (
	  module_id CHAR(7) NOT NULL,
	  course_id CHAR(7) NOT NULL,
	  PRIMARY KEY (module_id, course_id),
	  FOREIGN KEY (module_id) REFERENCES %I.module (module_id),
	  FOREIGN KEY (course_id) REFERENCES %I.course (course_id)
	);'
	, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE INDEX %I_idx_course_module_combined ON %I.course_module (course_id, module_id);'
	, schema_name, schema_name);

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
	CREATE TRIGGER %I_trigger_create_student_user
	AFTER INSERT ON %I.student
	FOR EACH ROW
	EXECUTE FUNCTION shared.create_student_user();'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE UNIQUE INDEX %I_idx_unique_student_personal_email ON %I.student (LOWER(student_personal_email));'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE INDEX %I_idx_student_id ON %I.student (student_id);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE INDEX %I_idx_student_attendance ON %I.student (student_attendance);'
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
	CREATE INDEX %I_idx_student_module_combined ON %I.student_module (student_id, module_id);'
	, schema_name, schema_name);

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
	CREATE INDEX %I_idx_session_date_time ON %I.session (session_date, session_start_time);'
	, schema_name, schema_name);

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
	CREATE INDEX %I_idx_student_session_id ON %I.student_session (session_id);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE INDEX %I_idx_attendance_record ON %I.student_session (attendance_record);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE INDEX %I_idx_attendance_record_true ON %I.student_session (session_id, student_id) WHERE attendance_record = TRUE;'
	, schema_name, schema_name);

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

	EXECUTE format('
	GRANT USAGE ON SCHEMA %I TO student_role;'
	, schema_name);

	EXECUTE format('
	GRANT USAGE ON SCHEMA %I TO staff_role;
	GRANT USAGE ON SCHEMA %I TO teaching_staff_role;'
	, schema_name, schema_name);

	EXECUTE format('
	GRANT SELECT ON %I.session, %I.student, %I.module TO teaching_staff_role;
	GRANT SELECT ON %I.student_session TO teaching_staff_role;'
	, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	GRANT UPDATE (attendance_record) ON %I.student_session TO teaching_staff_role;'
	, schema_name);

	EXECUTE format('
	GRANT USAGE ON SCHEMA %I TO admin_staff_role;'
	, schema_name);

	EXECUTE format('
	GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO admin_staff_role;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY course_student_view_policy
	ON shared.course
	FOR SELECT
	USING (course_id IN (SELECT course_id FROM %I.student_course WHERE student_id = CURRENT_USER));'
	, schema_name);

	EXECUTE format('
	CREATE POLICY module_student_view_policy
	ON shared.module
	FOR SELECT
	USING (module_id IN (SELECT module_id FROM %I.student_module WHERE student_id = CURRENT_USER));'
	, schema_name);

	EXECUTE format('
	CREATE POLICY assessment_student_view_policy
	ON shared.assessment
	FOR SELECT
	USING (module_id IN (SELECT module_id FROM %I.student_module WHERE student_id = CURRENT_USER));'
	, schema_name);

	EXECUTE format('
	CREATE POLICY emergency_contact_student_view_policy
	ON shared.emergency_contact
	FOR SELECT
	USING (contact_id IN (SELECT contact_id FROM %I.student_contact WHERE student_id = CURRENT_USER));'
	, schema_name);
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

/* CREATE SHARED ROLES */
-- Student role
CREATE ROLE student_role NOLOGIN;

-- Staff role
CREATE ROLE staff_role NOLOGIN;

-- Teaching staff role
CREATE ROLE teaching_staff_role NOLOGIN;

-- Admin staff role
CREATE ROLE admin_staff_role NOLOGIN;

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

-- Optimises queries and joins involving branches.
CREATE INDEX shared_idx_branch_id ON shared.branch (branch_id);

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

-- Speeds up searches or groupings involving course names
CREATE INDEX shared_idx_course_name ON shared.course (course_name);

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

-- Improves performance for grouping or searching based on module names in analytics views.
CREATE INDEX shared_idx_module_name ON shared.module (module_name);

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

/* ENABLE RLS AND CREATE FOR SHARED TABLES */
-- Branch Policy
ALTER TABLE shared.branch ENABLE ROW LEVEL SECURITY;

CREATE POLICY branch_staff_view_policy
ON shared.branch
FOR SELECT
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'branch'));

CREATE POLICY branch_admin_update_policy
ON shared.branch
FOR UPDATE
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'branch'));

-- Department Policy
ALTER TABLE shared.department ENABLE ROW LEVEL SECURITY;

CREATE POLICY department_staff_view_policy
ON shared.department
FOR SELECT
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'department'));

CREATE POLICY department_admin_full_policy
ON shared.department
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'department'));

-- Course Policy
ALTER TABLE shared.course ENABLE ROW LEVEL SECURITY;

CREATE POLICY course_staff_view_policy
ON shared.course
FOR SELECT
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'course'));

CREATE POLICY course_admin_full_policy
ON shared.course
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'course'));

-- Department Course Policy
ALTER TABLE shared.department_course ENABLE ROW LEVEL SECURITY;

CREATE POLICY department_course_staff_view_policy
ON shared.department_course
FOR SELECT
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'department_course'));

CREATE POLICY department_course_admin_full_policy
ON shared.department_course
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'department_course'));

-- Module Policy
ALTER TABLE shared.module ENABLE ROW LEVEL SECURITY;

CREATE POLICY module_admin_full_policy
ON shared.module
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'module'));

-- Course Module Policy
ALTER TABLE shared.course_module ENABLE ROW LEVEL SECURITY;

CREATE POLICY course_module_staff_view_policy
ON shared.course_module
FOR SELECT
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'course_module'));

CREATE POLICY course_module_admin_full_policy
ON shared.course_module
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'course_module'));

-- Assessment Policy
ALTER TABLE shared.assessment ENABLE ROW LEVEL SECURITY;

CREATE POLICY assessment_admin_full_policy
ON shared.assessment
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'assessment'));

-- Role Policy
ALTER TABLE shared.role ENABLE ROW LEVEL SECURITY;

CREATE POLICY role_admin_full_policy
ON shared.role
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'role'));

-- Facility Policty
ALTER TABLE shared.facility ENABLE ROW LEVEL SECURITY;

CREATE POLICY facility_staff_view_policy
ON shared.facility
FOR SELECT
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'facility'));

CREATE POLICY facility_admin_full_policy
ON shared.facility
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'facility'));

-- Room Type
ALTER TABLE shared.room_type ENABLE ROW LEVEL SECURITY;

CREATE POLICY room_type_staff_view_policy
ON shared.room_type
FOR SELECT
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'room_type'));

CREATE POLICY room_type_admin_full_policy
ON shared.room_type
FOR ALL
USING (CURRENT_USER IN (SELECT grantee FROM information_schema.role_table_grants WHERE table_name = 'room_type'));

-- Emergency Contact Policy
ALTER TABLE shared.emergency_contact ENABLE ROW LEVEL SECURITY;

/* Shared inserts */
-- Records of BRANCH
INSERT INTO shared.branch (branch_name, branch_status, branch_addr1, branch_addr2, branch_postcode, branch_contact_number, branch_email) 
VALUES
  ('SES London', 'Open', '123 High Street', 'Westminster', 'SW1A 1AA', '020 7946 0958', 'london@ses.edu.org');
  -- ('SES Manchester', 'Open', '45 Oxford Road', 'Manchester City Centre', 'M1 5QA', '0161 306 6000', 'manchester@ses.edu.org');

-- Records of DEPARTMENT
INSERT INTO shared.department (dep_name, dep_type, dep_description) 
VALUES
  ('Mathematics', 'Educational', 'Department of Mathematics'),
  ('Arts', 'Educational', 'Department of Arts'),
  ('Computing', 'Educational', 'Department of Computing'),
  ('Humanities', 'Educational', 'Department of Humanities'),
  ('Science', 'Educational', 'Department of Science'),
  ('Vocational Training', 'Educational', 'Department of Vocational Training'),
  ('Finance', 'Administrative', NULL),
  ('Facilities and Maintenance', 'Maintenance', NULL),
  ('SES Operations', 'Operational', 'Manages the SES operations and infrastructure'),
  ('Human Resources', 'Administrative', NULL);

-- Records of COURSE
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length)
VALUES
  ('Advanced Calculus', 'A deep dive into calculus, focusing on multivariable calculus and real analysis.', 'A-level Mathematics or equivalent.', 3),
  ('Machine Learning', 'An introduction to machine learning algorithms and their mathematical foundations.', 'A-level Mathematics and Programming experience.', 3 ),
  ('Modern Art Techniques', 'Explores various techniques and styles used in modern art, with practical workshops.', 'Portfolio submission required.', 3),
  ('Art History and Critique', 'A comprehensive study of art history from antiquity to the present day.', 'A-level History or equivalent.', 3),
  ('Software Engineering', 'Focuses on the principles of software design, testing, and project management.', 'A-level Mathematics or equivalent.', 3),
  ('Cybersecurity', 'An in-depth look at cybersecurity principles, including threat analysis and defense mechanisms.', 'A-level Mathematics and Programming experience.', 3),
  ('Philosophy and Ethics', 'Explores philosophical questions and their relevance to modern ethical issues.', 'A-level English Literature or equivalent.', 3),
  ('World History', 'A study of major historical events and their global impact.', 'A-level History or equivalent.', 3),
  ('Biotechnology', 'Covers the principles of biotechnology and its applications in healthcare and agriculture.', 'A-level Biology and Chemistry.', 3),
  ('Astrophysics', 'An introduction to the physics of stars, galaxies, and the universe.', 'A-level Mathematics and Physics.', 3),
  ('Culinary Arts', 'Provides training in professional cooking techniques and food safety.', 'Basic GCSEs required.', 2),
  ('Construction Technology', 'Covers modern construction techniques and safety protocols.', 'Basic GCSEs required.', 2);

-- Records of DEPARTMENT_COURSE
INSERT INTO shared.department_course (dep_id, course_id)
VALUES
  ('d000001' , 'c000001'),
  ('d000001' , 'c000002'),
  ('d000002' , 'c000003'),
  ('d000002' , 'c000004'),
  ('d000003' , 'c000005'),
  ('d000003' , 'c000006'),
  ('d000003' , 'c000002'),
  ('d000004' , 'c000007'),
  ('d000004' , 'c000008'),
  ('d000005' , 'c000009'),
  ('d000005' , 'c000010'),
  ('d000006' , 'c000011'),
  ('d000006' , 'c000012');

-- Records for MODULE
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration)
VALUES
  ('Multivariable Calculus', 'Explores multivariable functions, partial derivatives, and multiple integrals.', 'L7', 20, 'Active', '2024-12-01', 200.00, 2),
  ('Real Analysis', 'Covers limits, continuity, differentiation, and integration on real number sets.', 'L7', 20, 'Active', '2024-12-01', 180.00, 2),
  ('Supervised Learning', 'Introduction to supervised learning algorithms and their applications.', 'L4', 20, 'Active', '2024-12-01', 200.00, 2),
  ('Neural Networks', 'Covers the basics of artificial neural networks and deep learning.', 'L5', 20, 'Active', '2024-12-01', 190.00, 1),
  ('Abstract Painting', 'Hands-on techniques for creating abstract art.', 'L6', 20, 'Active', '2024-12-01', 200.00, 1),
  ('Digital Art Methods', 'Explores the use of digital tools in modern art creation.', 'L5', 20, 'Active', '2024-12-01', 140.00, 2),
  ('Renaissance Art', 'A study of Renaissance art and its historical significance.', 'L5', 20, 'Active', '2024-12-01', 180.00, 2),
  ('Contemporary Art Movements', 'Analysis of art movements in the 20th and 21st centuries.', 'L6', 20, 'Active', '2024-12-01', 170.00, 1),
  ('Agile Development', 'Covers principles and practices of Agile development.', 'L5', 20, 'Active', '2024-12-01', 180.00, 2),
  ('Software Testing', 'Focuses on testing methodologies and quality assurance.', 'L4', 20, 'Active', '2024-12-01', 190.00, 2),
  ('Cryptography', 'Introduction to cryptographic principles and practices.', 'L4', 20, 'Active', '2024-12-01', 200.00, 2),
  ('Network Security', 'Focuses on securing computer networks against threats.', 'L4', 20, 'Active', '2024-12-01', 190.00, 1),
  ('Moral Philosophy', 'Explores ethical theories and moral decision-making.', 'L5', 20, 'Active', '2024-12-01', 200.00, 1),
  ('Political Philosophy', 'Analyzes the philosophical foundations of political systems.', 'L5', 20, 'Active', '2024-12-01', 160.00, 2),
  ('Ancient Civilizations', 'Study of ancient civilizations and their cultural impact.', 'L5', 20, 'Active', '2024-12-01', 170.00, 2),
  ('Modern Conflicts', 'Examines key conflicts in modern history.', 'L6', 20, 'Active', '2024-12-01', 160.00, 1),
  ('Genetic Engineering', 'Introduction to genetic modification techniques.', 'L4', 20, 'Active', '2024-12-01', 200.00, 2),
  ('Bioinformatics', 'Covers computational tools for biological data analysis.', 'L6', 20, 'Active', '2024-12-01', 190.00, 2),
  ('Stellar Physics', 'Study of the physical properties of stars.', 'L4', 20, 'Active', '2024-12-01', 180.00, 2),
  ('Cosmology', 'Introduction to the study of the universe.', 'L4', 20, 'Active', '2024-12-01', 170.00, 1),
  ('Pastry Techniques', 'Covers the techniques for making pastries and desserts.', 'L5', 20, 'Active', '2024-12-01', 200.00, 1),
  ('Savory Dishes', 'Training in preparation of savory meals.', 'L6', 20, 'Active', '2024-12-01', 160.00, 2),
  ('Building Materials', 'Study of materials used in modern construction.', 'L5', 20, 'Active', '2024-12-01', 200.00, 2),
  ('Construction Safety', 'Focus on safety protocols and regulations.', 'L4', 20, 'Active', '2024-12-01', 160.00, 1);

-- Records for COURSE_MODULE
INSERT INTO shared.course_module (course_id, module_id) 
VALUES
  ('c000001', 'm000001'),
  ('c000001', 'm000002'),
  ('c000002', 'm000003'),
  ('c000002', 'm000004'),
  ('c000003', 'm000005'),
  ('c000003', 'm000006'),
  ('c000004', 'm000007'),
  ('c000004', 'm000008'),
  ('c000005', 'm000009'),
  ('c000005', 'm000010'),
  ('c000006', 'm000011'),
  ('c000006', 'm000012'),
  ('c000007', 'm000013'),
  ('c000007', 'm000014'),
  ('c000008', 'm000015'),
  ('c000008', 'm000016'),
  ('c000009', 'm000017'),
  ('c000009', 'm000018'),
  ('c000010', 'm000019'),
  ('c000010', 'm000020'),
  ('c000011', 'm000021'),
  ('c000011', 'm000022'),
  ('c000012', 'm000023'),
  ('c000012', 'm000024');

-- Records for ASSESSMENT
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment)
VALUES
  ('m000001', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000001', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000001', 'Coursework Project',  NULL, 'Coursework', 50.00, NULL),
  ('m000001', 'Essay', NULL, 'Essay', 30.00, NULL),
  ('m000001', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000001', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000002', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000002', 'Final Exam',  NULL, 'Exam', 50.00, NULL),
  ('m000002', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL),
  ('m000002', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000002', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000002', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000003', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000003', 'Final Exam',  NULL, 'Exam', 50.00, NULL),
  ('m000003', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000003', 'Essay', NULL, 'Essay', 30.00, NULL),
  ('m000003', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000003', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000004', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000004', 'Final Exam',  NULL, 'Exam', 50.00, NULL),
  ('m000004', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000004', 'Essay', NULL, 'Essay', 30.00, NULL),
  ('m000004', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000004', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000005', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000005', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000005', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000005', 'Essay', NULL, 'Essay', 30.00, NULL),
  ('m000005', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000005', 'Presentation', NULL, 'Presentation', 50.00, NULL),
  ('m000006', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000006', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000006', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000006', 'Essay', NULL, 'Essay', 50.00, NULL),
  ('m000006', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000006', 'Presentation', NULL, 'Presentation', 30.00, NULL),
  ('m000007', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000007', 'Final Exam',  NULL, 'Exam', 30.00, NULL),
  ('m000007', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000007', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000007', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000007', 'Presentation', NULL, 'Presentation', 50.00, NULL),
  ('m000008', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000008', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000008', 'Coursework Project',  NULL, 'Coursework', 50.00, NULL),
  ('m000008', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000008', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000008', 'Presentation', NULL, 'Presentation', 30.00, NULL),
  ('m000009', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000009', 'Final Exam',  NULL, 'Exam', 50.00, NULL),
  ('m000009', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL),
  ('m000009', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000009', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000009', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000010', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000010', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000010', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000010', 'Essay', NULL, 'Essay', 50.00, NULL),
  ('m000010', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000010', 'Presentation', NULL, 'Presentation', 30.00, NULL),
  ('m000011', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000011', 'Final Exam',  NULL, 'Exam', 30.00, NULL),
  ('m000011', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000011', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000011', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000011', 'Presentation', NULL, 'Presentation', 50.00, NULL),
  ('m000012', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000012', 'Final Exam',  NULL, 'Exam', 50.00, NULL),
  ('m000012', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000012', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000012', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000012', 'Presentation', NULL, 'Presentation', 30.00, NULL),
  ('m000013', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000013', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000013', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL),
  ('m000013', 'Essay', NULL, 'Essay', 50.00, NULL),
  ('m000013', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000013', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000014', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000014', 'Final Exam',  NULL, 'Exam', 50.00, NULL),
  ('m000014', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL),
  ('m000014', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000014', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000014', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000015', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000015', 'Final Exam',  NULL, 'Exam', 50.00, NULL),
  ('m000015', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000015', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000015', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000015', 'Presentation', NULL, 'Presentation', 30.00, NULL),
  ('m000016', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000016', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000016', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL),
  ('m000016', 'Essay', NULL, 'Essay', 50.00, NULL),
  ('m000016', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000016', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000017', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000017', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000017', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000017', 'Essay', NULL, 'Essay', 50.00, NULL),
  ('m000017', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000017', 'Presentation', NULL, 'Presentation', 30.00, NULL),
  ('m000018', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000018', 'Final Exam',  NULL, 'Exam', 30.00, NULL),
  ('m000018', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000018', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000018', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000018', 'Presentation', NULL, 'Presentation', 50.00, NULL),
  ('m000019', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000019', 'Final Exam',  NULL, 'Exam', 30.00, NULL),
  ('m000019', 'Coursework Project',  NULL, 'Coursework', 50.00, NULL),
  ('m000019', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000019', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000019', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000020', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000020', 'Final Exam',  NULL, 'Exam', 50.00, NULL),
  ('m000020', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL),
  ('m000020', 'Essay', NULL, 'Essay', 10.00, NULL),
  ('m000020', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000020', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000021', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000021', 'Final Exam',  NULL, 'Exam', 10.00, NULL),
  ('m000021', 'Coursework Project',  NULL, 'Coursework', 50.00, NULL),
  ('m000021', 'Essay', NULL, 'Essay', 30.00, NULL),
  ('m000021', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000021', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000022', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000022', 'Final Exam',  NULL, 'Exam', 30.00, NULL),
  ('m000022', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000022', 'Essay', NULL, 'Essay', 50.00, NULL),
  ('m000022', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000022', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000023', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000023', 'Final Exam',  NULL, 'Exam', 30.00, NULL),
  ('m000023', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000023', 'Essay', NULL, 'Essay', 50.00, NULL),
  ('m000023', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000023', 'Presentation', NULL, 'Presentation', 10.00, NULL),
  ('m000024', 'General Exam', NULL, 'Exam', 0.00, NULL),
  ('m000024', 'Final Exam',  NULL, 'Exam', 30.00, NULL),
  ('m000024', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL),
  ('m000024', 'Essay', NULL, 'Essay', 50.00, NULL),
  ('m000024', 'Research Essay', NULL, 'Essay', 0.00, NULL),
  ('m000024', 'Presentation', NULL, 'Presentation', 10.00, NULL);

-- Records for ROLE
INSERT INTO shared.role (role_name) 
VALUES 
  ('Lecturer'),
  ('Teaching Assistant'),
  ('Accountant'),
  ('Human Resources Manager'),
  ('Recruiter'),
  ('IT Support Specialist'),
  ('Facilities Manager'),
  ('Security Officer'),
  ('Library Assistant'),
  ('Receptionist'),
  ('Maintenance Technician'),
  ('Groundskeeper'),
	('Admin staff');   

-- Records for FACILITY
INSERT INTO shared.facility (facility_total_quantity, facility_name)
VALUES
  (100, 'Desktop Computers'),
  (20, 'Projectors'),
  (200, 'Whiteboards'),
  (5, '3D Printers'),
  (15, 'Microscopes'),
  (25, 'Easels'),
  (30, 'Sound Systems'),
  (40, 'Keyboards and Musical Instruments'),
  (10, 'Cooking Stations'),
  (10, 'Workshop Tools and Machines'),
  (12, 'Sports Equipment Sets'),
  (20, 'Printers and Scanners');

-- Records for ROOM_TYPE
INSERT INTO shared.room_type (type_name, type_description)
VALUES
  ('Lecture Theatre', 'Large room equipped with seating for lectures and presentations.'),
  ('Seminar Room', 'Medium-sized room designed for seminars, group discussions, and workshops.'),
  ('Laboratory', 'Room equipped with specialized tools and equipment for experiments and practical sessions.'),
  ('Computer Lab', 'Room with computers and software for programming, simulations, and digital training.'),
  ('Art Studio', 'Creative space for art and design activities, equipped with easels and materials.'),
  ('Music Room', 'Room designed for music practice and lessons, with soundproofing and instruments.'),
  ('Conference Room', 'Room for formal meetings, discussions, and small conferences.'),
  ('Library', 'Quiet space with resources for reading, studying, and research.'),
  ('Cafeteria', 'Dining area for students and staff, serving meals and refreshments.'),
  ('Sports Hall', 'Indoor facility for physical activities and sports events.'),
  ('Workshop', 'Room equipped for vocational training, including tools and machinery.'),
  ('Examination Hall', 'Room designed for hosting exams and assessments with individual desks.'),
  ('Office', NULL);

-- Records for EMERGENCY_CONTACT
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship)
VALUES
  ('emily.jones@gmail.com', '07400123456', 'Emily', NULL, 'Jones', '12 Apple Street', 'Flat 4', 'London', 'E1 7HP', 'Mother'),
  ('john.smith@yahoo.com', '07411123456', 'John', NULL, 'Smith', '23 Pear Lane', NULL, 'Manchester', 'M2 5NG', 'Father'),
  ('lisa.brown@hotmail.com', '07422123456', 'Lisa', 'Marie', 'Brown', '56 Orange Avenue', 'Apt B', 'Birmingham', 'B12 8PP', 'Sister'),
  ('michael.green@gmail.com', '07433123456', 'Michael', NULL, 'Green', '78 Plum Road', NULL, 'Leeds', 'LS1 4LT', 'Brother'),
  ('sarah.white@yahoo.com', '07444123456', 'Sarah', 'Anne', 'White', '34 Peach Street', NULL, 'Bristol', 'BS1 3AU', 'Aunt'),
  ('david.taylor@hotmail.com', '07455123456', 'David', NULL, 'Taylor', '90 Grape Lane', 'Unit 5', 'Liverpool', 'L1 8JH', 'Uncle'),
  ('jessica.evans@gmail.com', '07466123456', 'Jessica', 'May', 'Evans', '12 Lime Grove', NULL, 'Glasgow', 'G2 8AZ', 'Friend'),
  ('mark.johnson@yahoo.com', '07477123456', 'Mark', NULL, 'Johnson', '33 Berry Street', NULL, 'Edinburgh', 'EH1 2AD', 'Cousin'),
  ('laura.moore@hotmail.com', '07488123456', 'Laura', NULL, 'Moore', '45 Kiwi Road', NULL, 'Cardiff', 'CF10 1AN', 'Colleague'),
  ('steven.harris@gmail.com', '07499123456', 'Steven', 'John', 'Harris', '22 Cherry Lane', NULL, 'Newcastle', 'NE1 3AF', 'Friend'),
  ('anna.clark@yahoo.com', '07500123456', 'Anna', NULL, 'Clark', '11 Maple Drive', NULL, 'Sheffield', 'S1 4DN', 'Niece'),
  ('robert.lewis@hotmail.com', '07511123456', 'Robert', NULL, 'Lewis', '60 Oak Street', NULL, 'Glasgow', 'G3 7HZ', 'Nephew'),
  ('hannah.walker@gmail.com', '07522123456', 'Hannah', NULL, 'Walker', '14 Pine Road', NULL, 'Manchester', 'M14 6QT', 'Cousin'),
  ('thomas.wright@yahoo.com', '07533123456', 'Thomas', NULL, 'Wright', '99 Willow Way', NULL, 'Bristol', 'BS8 2HL', 'Brother'),
  ('megan.james@hotmail.com', '07544123456', 'Megan', NULL, 'James', '88 Cedar Drive', NULL, 'Liverpool', 'L3 5HA', 'Friend'),
  ('charlie.scott@gmail.com', '07555123456', 'Charlie', 'Anne', 'Scott', '77 Maple Lane', NULL, 'Cardiff', 'CF14 2AB', 'Sister'),
  ('isabelle.morris@yahoo.com', '07566123456', 'Isabelle', NULL, 'Morris', '66 Birch Street', NULL, 'Sheffield', 'S2 3FL', 'Aunt'),
  ('matthew.taylor@hotmail.com', '07577123456', 'Matthew', NULL, 'Taylor', '55 Elm Avenue', NULL, 'Newcastle', 'NE6 4BL', 'Uncle'),
  ('rachel.johnson@gmail.com', '07588123456', 'Rachel', NULL, 'Johnson', '44 Hazel Grove', NULL, 'Edinburgh', 'EH2 4DN', 'Friend'),
  ('oliver.hall@yahoo.com', '07599123456', 'Oliver', NULL, 'Hall', '33 Cherry Lane', NULL, 'Birmingham', 'B11 2AF', 'Colleague'),
  ('sophie.anderson@hotmail.com', '07600123456', 'Sophie', NULL, 'Anderson', '22 Peach Street', NULL, 'London', 'E5 9GF', 'Mother'),
  ('benjamin.kim@gmail.com', '07611123456', 'Benjamin', 'Lee', 'Kim', '11 Pine Road', NULL, 'Leeds', 'LS4 2EF', 'Father'),
  ('zoe.baker@yahoo.com', '07622123456', 'Zoe', NULL, 'Baker', '50 Palm Avenue', NULL, 'Bristol', 'BS3 5GH', 'Sister'),
  ('alexander.martinez@hotmail.com', '07633123456', 'Alexander', NULL, 'Martinez', '31 Orchid Lane', NULL, 'Glasgow', 'G41 2QH', 'Brother'),
  ('victoria.lee@gmail.com', '07644123456', 'Victoria', NULL, 'Lee', '29 Magnolia Street', NULL, 'Manchester', 'M16 4FE', 'Aunt'),
  ('luke.davis@yahoo.com', '07655123456', 'Luke', NULL, 'Davis', '89 Willow Way', NULL, 'Cardiff', 'CF15 5HP', 'Uncle'),
  ('natalie.carter@hotmail.com', '07666123456', 'Natalie', NULL, 'Carter', '15 Elm Road', NULL, 'Edinburgh', 'EH3 5JQ', 'Friend'),
  ('chloe.harris@gmail.com', '07677123456', 'Chloe', NULL, 'Harris', '60 Peach Lane', NULL, 'Liverpool', 'L5 1AD', 'Cousin'),
  ('daniel.thomas@yahoo.com', '07688123456', 'Daniel', NULL, 'Thomas', '8 Maple Grove', NULL, 'Birmingham', 'B19 2XT', 'Colleague'),
  ('madison.mitchell@hotmail.com', '07699123456', 'Madison', NULL, 'Mitchell', '7 Cherry Street', NULL, 'Newcastle', 'NE2 3QY', 'Sister'),
  ('nathan.miller@gmail.com', '07700123456', 'Nathan', NULL, 'Miller', '4 Birch Lane', NULL, 'Sheffield', 'S1 9PL', 'Brother');

/* Branch b01 inserts */

-- Records of STAFF
INSERT INTO branch_b01.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile, staff_dob)
VALUES
  ('Sophie', NULL, 'Roberts', 'Dr', '123 Maple Street', NULL, 'London', 'SW1A 2AA', 'sophie.roberts@gmail.com', '0113256780', '07912345679', '1988-09-15'),
  ('John', NULL, 'Smith', 'Dr', '789 Elm Street', NULL, 'London', 'SW1A 2AA', 'john.smith@gmail.com', '0201234567', '07891234567', '1980-03-25'),
  ('David', NULL, 'Clark', 'Dr', '789 Pine Avenue', NULL, 'Bristol', 'BS1 1AA', 'david.clark@gmail.com', '0123456789', '07712345678', '1978-09-12'),
  ('Michael', NULL, 'Johnson', 'Dr', '123 Cedar Street', NULL, 'London', 'SW1A 2AA', 'michael.johnson@gmail.com', '0131234567', '07723456789', '1983-02-15'),
  ('Emily', 'Grace', 'Wilson', 'Dr', '789 Oak Lane', NULL, 'Glasgow', 'G2 1AB', 'emily.wilson@gmail.com', '0113256781', '07912345680', '1982-06-25'),
  ('Noah', 'Edward', 'Wilson', 'Dr', '123 Birch Avenue', NULL, 'London', 'SW1A 2AB', 'noah.wilson@gmail.com', '0203456790', '07892345679', '1976-06-30'),
  ('Amelia', NULL, 'Thompson', 'Dr', '456 Oak Avenue', NULL, 'Manchester', 'M1 1AA', 'amelia.thompson@gmail.com', '0202345678', '07891234568', '1978-08-05');

-- Records of STAFF_ROLE
INSERT INTO branch_b01.staff_role (staff_id, role_id)
VALUES
  ('s000000001', 1),
  ('s000000002', 2),
  ('s000000003', 1),
  ('s000000004', 2),
  ('s000000005', 3),
  ('s000000006', 4),
  ('s000000007', 6);

-- Records of DEPARTMENT
INSERT INTO branch_b01.department (dep_id, staff_id)
VALUES
  ('d000001', 's000000001'),
  ('d000003', 's000000003'),
  ('d000007', 's000000005'),
  ('d000010', 's000000006'),
  ('d000009', 's000000007');

-- Records of COURSE
INSERT INTO branch_b01.course (course_id, staff_id)
VALUES
  ('c000001', 's000000001'),
  ('c000002', 's000000001'),
  ('c000005', 's000000003'),
  ('c000006', 's000000003');

-- Records of DEPARTMENT_COURSE
INSERT INTO branch_b01.department_course (dep_id, course_id)
VALUES
  ('d000001' , 'c000001'),
  ('d000001' , 'c000002'),
  ('d000003' , 'c000005'),
  ('d000003' , 'c000006'),
  ('d000003' , 'c000002');

-- Records of MODULE
INSERT INTO branch_b01.module (module_id)
VALUES
  ('m000001'),
  ('m000002'),
  ('m000003'),
  ('m000004'),
  ('m000009'),
  ('m000010'),
  ('m000011'),
  ('m000012');

-- Records of COURSE_MODULE
INSERT INTO branch_b01.course_module (course_id, module_id) 
VALUES
  ('c000001', 'm000001'),
  ('c000001', 'm000002'),
  ('c000002', 'm000003'),
  ('c000002', 'm000004'),
  ('c000005', 'm000009'),
  ('c000005', 'm000010'),
  ('c000006', 'm000011'),
  ('c000006', 'm000012');

-- Records of STUDENT
INSERT INTO branch_b01.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_dob, student_attendance)
VALUES
  ('alex.braun@gmail.com', 'Alex', NULL, 'Braun', 'He/Him', '123 Main Street', 'Mayfair', 'London', 'SW1A 1AA', '0201234570', '07891234572', '2003-05-15', 0.00),
  ('jane.smith@outlook.com', 'Jane', NULL, 'Smith', 'She/Her', '456 Park Avenue', NULL, 'Manchester', 'M1 1AA', '0161234569', '07987654323', '2002-10-20', 0.00),
  ('JOHN.doe@yahoo.com', 'John', 'James', 'Doe', 'He/Him', '123 Main Street', 'Kensington', 'London', 'SW1A 1AA', '0201234571', '07891234573', '2001-05-15', 0.00),
  ('emily.johnson@mail.co.uk', 'Emily', NULL, 'Johnson', 'She/Her', '789 Oak Lane', NULL, 'Birmingham', 'B1 1AA', '0123456789', '07712345678', '2003-08-18', 0.00),
  ('michael.brown@gmail.com', 'Michael', 'Luke', 'Brown', 'He/Him', '1010 Maple Street', NULL, 'Edinburgh', 'EH1 1AA', '0131234567', '07723456789', '2001-12-03', 0.00),
  ('emma.williams@gmail.com', 'Emma', NULL, 'Williams', 'She/Her', '789 Cedar Street', NULL, 'London', 'SW1A 2AB', '0203456789', '07892345678', '2003-04-15', 0.00);

-- Records of STUDENT_COURSE
INSERT INTO branch_b01.student_course (student_id, course_id, feedback, culmative_average, course_rep)
VALUES
  ('sn00000001', 'c000001', NULL, 0.00, TRUE),
  ('sn00000002', 'c000001', NULL, 0.00, FALSE),
  ('sn00000003', 'c000002', NULL, 0.00, TRUE),
  ('sn00000004', 'c000002', NULL, 0.00, FALSE),
  ('sn00000005', 'c000005', NULL, 0.00, FALSE),
  ('sn00000006', 'c000006', NULL, 0.00, FALSE);

-- Records of TUITION
INSERT INTO branch_b01.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline)
VALUES
  (2800.00, 0, 2800.00, 0, '2025-07-01'),
  (2900.00, 0, 2900.00, 0, '2025-08-05'),
  (3000.00, 0, 3000.00, 0, '2025-07-10'),
  (3100.00, 0, 3100.00, 0, '2025-08-15'),
  (3200.00, 0, 3200.00, 0, '2025-07-20'),
  (3300.00, 0, 3300.00, 0, '2025-08-25');

-- Records of STUDENT_TUITION
INSERT INTO branch_b01.student_tuition (student_id, tuition_id)
VALUES
  ('sn00000001', 1),
  ('sn00000002', 2),
  ('sn00000003', 3),
  ('sn00000004', 4),
  ('sn00000005', 5),
  ('sn00000006', 6);

-- Records of TUITION_PAYMENT
INSERT INTO branch_b01.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method)
VALUES
  (1, 300.00, '2025-03-15', 'Bank Transfer'),
  (2, 200.00, '2025-03-20', 'Bank Transfer'),
  (3, 400.00, '2025-04-10', 'Direct Debit'),
  (4, 600.00, '2025-04-20', 'Direct Debit'),
  (5, 500.00, '2025-05-10', 'Direct Debit'),
  (6, 200.00, '2025-05-20', 'Direct Debit');

-- Records of STAFF_DEPARTMENT
INSERT INTO branch_b01.staff_department (staff_id, dep_id, date_assinged)
VALUES
  ('s000000001', 'd000001', '2025-02-01'),
  ('s000000002', 'd000001', '2025-02-02'),
  ('s000000003', 'd000003', '2025-03-02'),
  ('s000000004', 'd000003', '2025-02-06'),
  ('s000000005', 'd000007', '2025-04-02'),
  ('s000000006', 'd000010', '2025-02-09'),
  ('s000000007', 'd000009', '2025-05-02');

-- Records of BUILDING
INSERT INTO branch_b01.building (building_name, building_alt_name, building_type, building_addr1, building_addr2, building_city, building_postcode, building_country)
VALUES
  ('Turing Hall', 'TH', 'Educational', '12 Science Way', 'South Bank', 'London', 'SW1A 1AA', 'United Kingdom'),
  ('Ada Lovelace Building', 'ALB', 'Administrative', '98 King Street', 'Mayfair', 'London', 'SW1A 1AB', 'United Kingdom');

-- Records of ROOM
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor)
VALUES
  (1, 'Lecture Theatre 1', 'LT1', 1, 100, 1),
  (1, '1.02', 'TH1.01', 4, 40, 1),
  (1, '1.04', 'TH1.02', 2, 25, 1),
  (1, '2.01', 'TH2.01', 13, 1, 2),
  (1, '2.02', 'TH2.02', 13, 1, 2),
  (1, '2.03', 'TH2.03', 13, 1, 2),
  (1, '2.04', 'TH2.04', 13, 1, 2),
  (2, '1.05', 'ALB1.01', 13, 1, 1),
  (2, '1.05', 'ALB1.02', 13, 1, 1),
  (2, '1.05', 'ALB1.03', 13, 1, 1),
  (2, '1.05', 'ALB1.04', 13, 1, 1),
  (2, '2.01', 'ALB2.01', 13, 1, 2),
  (2, '2.02', 'ALB2.02', 13, 1, 2),
  (2, '2.03', 'ALB2.03', 13, 1, 2),
  (2, '2.04', 'ALB2.04', 13, 1, 2);

-- Records of ROOM_FACILITY
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity)
VALUES
  (1, 1, 1),
  (1, 2, 2),
  (2, 1, 25),
  (2, 2, 2),
  (2, 12, 2),
  (3, 1, 10),
  (3, 2, 2),
  (4, 1, 1),
  (5, 1, 1),
  (6, 1, 1),
  (7, 1, 1),
  (8, 1, 1),
  (9, 1, 1),
  (10, 1, 1),
  (11, 1, 1),
  (12, 1, 1),
  (13, 1, 1),
  (14, 1, 1),
  (15, 1, 1);

-- Records of SESSION
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description)
VALUES
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-11-05', '', TRUE, ''),
	(2, 'm000001', 'Practical', '10:00', '11:00', '2024-11-05', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-11-12', '', TRUE, ''),
	(2, 'm000001', 'Practical', '10:00', '11:00', '2024-11-12', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-11-19', '', TRUE, ''),
	(2, 'm000001', 'Practical', '10:00', '11:00', '2024-11-19', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-11-26', '', TRUE, ''),
	(3, 'm000001', 'Practical', '10:00', '11:00', '2024-11-26', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-03', '', TRUE, ''),
	(3, 'm000001', 'Practical', '10:00', '11:00', '2024-12-03', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-10', '', TRUE, ''),
	(3, 'm000001', 'Practical', '10:00', '11:00', '2024-12-10', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-17', '', TRUE, ''),
	(2, 'm000001', 'Practical', '10:00', '11:00', '2024-12-17', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-24', '', TRUE, ''),
	(2, 'm000001', 'Practical', '10:00', '11:00', '2024-12-24', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-31', '', TRUE, ''),
	(2, 'm000001', 'Practical', '10:00', '11:00', '2024-12-31', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2025-01-07', '', TRUE, ''),
	(2, 'm000001', 'Practical', '10:00', '11:00', '2025-01-07', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2025-01-14', '', TRUE, ''),
	(2, 'm000001', 'Practical', '10:00', '11:00', '2025-01-14', '', TRUE, ''),
	(1, 'm000001', 'Lecture', '9:00', '10:00', '2025-01-21', '', TRUE, ''),
	(3, 'm000001', 'Practical', '10:00', '11:00', '2025-01-21', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-11-05', '', TRUE, ''),
	(2, 'm000002', 'Practical', '11:00', '12:00', '2024-11-05', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-11-12', '', TRUE, ''),
	(2, 'm000002', 'Practical', '11:00', '12:00', '2024-11-12', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-11-19', '', TRUE, ''),
	(3, 'm000002', 'Practical', '11:00', '12:00', '2024-11-19', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-11-26', '', TRUE, ''),
	(2, 'm000002', 'Practical', '11:00', '12:00', '2024-11-26', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-03', '', TRUE, ''),
	(3, 'm000002', 'Practical', '11:00', '12:00', '2024-12-03', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-10', '', TRUE, ''),
	(3, 'm000002', 'Practical', '11:00', '12:00', '2024-12-10', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-17', '', TRUE, ''),
	(2, 'm000002', 'Practical', '11:00', '12:00', '2024-12-17', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-24', '', TRUE, ''),
	(2, 'm000002', 'Practical', '11:00', '12:00', '2024-12-24', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-31', '', TRUE, ''),
	(3, 'm000002', 'Practical', '11:00', '12:00', '2024-12-31', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2025-01-07', '', TRUE, ''),
	(3, 'm000002', 'Practical', '11:00', '12:00', '2025-01-07', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2025-01-14', '', TRUE, ''),
	(2, 'm000002', 'Practical', '11:00', '12:00', '2025-01-14', '', TRUE, ''),
	(1, 'm000002', 'Lecture', '10:00', '11:00', '2025-01-21', '', TRUE, ''),
	(3, 'm000002', 'Practical', '11:00', '12:00', '2025-01-21', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-11-05', '', TRUE, ''),
	(2, 'm000003', 'Practical', '12:00', '13:00', '2024-11-05', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-11-12', '', TRUE, ''),
	(2, 'm000003', 'Practical', '12:00', '13:00', '2024-11-12', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-11-19', '', TRUE, ''),
	(3, 'm000003', 'Practical', '12:00', '13:00', '2024-11-19', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-11-26', '', TRUE, ''),
	(2, 'm000003', 'Practical', '12:00', '13:00', '2024-11-26', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-03', '', TRUE, ''),
	(3, 'm000003', 'Practical', '12:00', '13:00', '2024-12-03', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-10', '', TRUE, ''),
	(2, 'm000003', 'Practical', '12:00', '13:00', '2024-12-10', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-17', '', TRUE, ''),
	(2, 'm000003', 'Practical', '12:00', '13:00', '2024-12-17', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-24', '', TRUE, ''),
	(2, 'm000003', 'Practical', '12:00', '13:00', '2024-12-24', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-31', '', TRUE, ''),
	(3, 'm000003', 'Practical', '12:00', '13:00', '2024-12-31', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2025-01-07', '', TRUE, ''),
	(2, 'm000003', 'Practical', '12:00', '13:00', '2025-01-07', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2025-01-14', '', TRUE, ''),
	(3, 'm000003', 'Practical', '12:00', '13:00', '2025-01-14', '', TRUE, ''),
	(1, 'm000003', 'Lecture', '11:00', '12:00', '2025-01-21', '', TRUE, ''),
	(2, 'm000003', 'Practical', '12:00', '13:00', '2025-01-21', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-11-05', '', TRUE, ''),
	(2, 'm000004', 'Practical', '13:00', '14:00', '2024-11-05', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-11-12', '', TRUE, ''),
	(3, 'm000004', 'Practical', '13:00', '14:00', '2024-11-12', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-11-19', '', TRUE, ''),
	(2, 'm000004', 'Practical', '13:00', '14:00', '2024-11-19', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-11-26', '', TRUE, ''),
	(2, 'm000004', 'Practical', '13:00', '14:00', '2024-11-26', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-03', '', TRUE, ''),
	(2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-03', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-10', '', TRUE, ''),
	(2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-10', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-17', '', TRUE, ''),
	(2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-17', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-24', '', TRUE, ''),
	(2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-24', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-31', '', TRUE, ''),
	(2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-31', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2025-01-07', '', TRUE, ''),
	(3, 'm000004', 'Practical', '13:00', '14:00', '2025-01-07', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2025-01-14', '', TRUE, ''),
	(3, 'm000004', 'Practical', '13:00', '14:00', '2025-01-14', '', TRUE, ''),
	(1, 'm000004', 'Lecture', '12:00', '13:00', '2025-01-21', '', TRUE, ''),
	(3, 'm000004', 'Practical', '13:00', '14:00', '2025-01-21', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-11-05', '', TRUE, ''),
	(3, 'm000009', 'Practical', '14:00', '15:00', '2024-11-05', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-11-12', '', TRUE, ''),
	(3, 'm000009', 'Practical', '14:00', '15:00', '2024-11-12', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-11-19', '', TRUE, ''),
	(3, 'm000009', 'Practical', '14:00', '15:00', '2024-11-19', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-11-26', '', TRUE, ''),
	(3, 'm000009', 'Practical', '14:00', '15:00', '2024-11-26', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-03', '', TRUE, ''),
	(2, 'm000009', 'Practical', '14:00', '15:00', '2024-12-03', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-10', '', TRUE, ''),
	(3, 'm000009', 'Practical', '14:00', '15:00', '2024-12-10', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-17', '', TRUE, ''),
	(2, 'm000009', 'Practical', '14:00', '15:00', '2024-12-17', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-24', '', TRUE, ''),
	(2, 'm000009', 'Practical', '14:00', '15:00', '2024-12-24', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-31', '', TRUE, ''),
	(2, 'm000009', 'Practical', '14:00', '15:00', '2024-12-31', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2025-01-07', '', TRUE, ''),
	(2, 'm000009', 'Practical', '14:00', '15:00', '2025-01-07', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2025-01-14', '', TRUE, ''),
	(2, 'm000009', 'Practical', '14:00', '15:00', '2025-01-14', '', TRUE, ''),
	(1, 'm000009', 'Lecture', '13:00', '14:00', '2025-01-21', '', TRUE, ''),
	(3, 'm000009', 'Practical', '14:00', '15:00', '2025-01-21', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-11-05', '', TRUE, ''),
	(3, 'm000010', 'Practical', '15:00', '16:00', '2024-11-05', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-11-12', '', TRUE, ''),
	(3, 'm000010', 'Practical', '15:00', '16:00', '2024-11-12', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-11-19', '', TRUE, ''),
	(2, 'm000010', 'Practical', '15:00', '16:00', '2024-11-19', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-11-26', '', TRUE, ''),
	(2, 'm000010', 'Practical', '15:00', '16:00', '2024-11-26', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-03', '', TRUE, ''),
	(3, 'm000010', 'Practical', '15:00', '16:00', '2024-12-03', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-10', '', TRUE, ''),
	(2, 'm000010', 'Practical', '15:00', '16:00', '2024-12-10', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-17', '', TRUE, ''),
	(2, 'm000010', 'Practical', '15:00', '16:00', '2024-12-17', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-24', '', TRUE, ''),
	(2, 'm000010', 'Practical', '15:00', '16:00', '2024-12-24', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-31', '', TRUE, ''),
	(3, 'm000010', 'Practical', '15:00', '16:00', '2024-12-31', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2025-01-07', '', TRUE, ''),
	(2, 'm000010', 'Practical', '15:00', '16:00', '2025-01-07', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2025-01-14', '', TRUE, ''),
	(2, 'm000010', 'Practical', '15:00', '16:00', '2025-01-14', '', TRUE, ''),
	(1, 'm000010', 'Lecture', '14:00', '15:00', '2025-01-21', '', TRUE, ''),
	(3, 'm000010', 'Practical', '15:00', '16:00', '2025-01-21', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-11-05', '', TRUE, ''),
	(3, 'm000011', 'Practical', '16:00', '17:00', '2024-11-05', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-11-12', '', TRUE, ''),
	(3, 'm000011', 'Practical', '16:00', '17:00', '2024-11-12', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-11-19', '', TRUE, ''),
	(2, 'm000011', 'Practical', '16:00', '17:00', '2024-11-19', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-11-26', '', TRUE, ''),
	(3, 'm000011', 'Practical', '16:00', '17:00', '2024-11-26', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-03', '', TRUE, ''),
	(2, 'm000011', 'Practical', '16:00', '17:00', '2024-12-03', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-10', '', TRUE, ''),
	(3, 'm000011', 'Practical', '16:00', '17:00', '2024-12-10', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-17', '', TRUE, ''),
	(3, 'm000011', 'Practical', '16:00', '17:00', '2024-12-17', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-24', '', TRUE, ''),
	(2, 'm000011', 'Practical', '16:00', '17:00', '2024-12-24', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-31', '', TRUE, ''),
	(2, 'm000011', 'Practical', '16:00', '17:00', '2024-12-31', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2025-01-07', '', TRUE, ''),
	(2, 'm000011', 'Practical', '16:00', '17:00', '2025-01-07', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2025-01-14', '', TRUE, ''),
	(2, 'm000011', 'Practical', '16:00', '17:00', '2025-01-14', '', TRUE, ''),
	(1, 'm000011', 'Lecture', '15:00', '16:00', '2025-01-21', '', TRUE, ''),
	(3, 'm000011', 'Practical', '16:00', '17:00', '2025-01-21', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-11-05', '', TRUE, ''),
	(2, 'm000012', 'Practical', '17:00', '18:00', '2024-11-05', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-11-12', '', TRUE, ''),
	(3, 'm000012', 'Practical', '17:00', '18:00', '2024-11-12', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-11-19', '', TRUE, ''),
	(3, 'm000012', 'Practical', '17:00', '18:00', '2024-11-19', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-11-26', '', TRUE, ''),
	(3, 'm000012', 'Practical', '17:00', '18:00', '2024-11-26', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-03', '', TRUE, ''),
	(2, 'm000012', 'Practical', '17:00', '18:00', '2024-12-03', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-10', '', TRUE, ''),
	(2, 'm000012', 'Practical', '17:00', '18:00', '2024-12-10', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-17', '', TRUE, ''),
	(3, 'm000012', 'Practical', '17:00', '18:00', '2024-12-17', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-24', '', TRUE, ''),
	(2, 'm000012', 'Practical', '17:00', '18:00', '2024-12-24', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-31', '', TRUE, ''),
	(3, 'm000012', 'Practical', '17:00', '18:00', '2024-12-31', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2025-01-07', '', TRUE, ''),
	(2, 'm000012', 'Practical', '17:00', '18:00', '2025-01-07', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2025-01-14', '', TRUE, ''),
	(2, 'm000012', 'Practical', '17:00', '18:00', '2025-01-14', '', TRUE, ''),
	(1, 'm000012', 'Lecture', '16:00', '17:00', '2025-01-21', '', TRUE, ''),
	(3, 'm000012', 'Practical', '17:00', '18:00', '2025-01-21', '', TRUE, '');

-- Records of STAFF_SESSION
INSERT INTO branch_b01.staff_session (staff_id, session_id)
VALUES
	('s000000001', 'sesh000001'),
	('s000000002', 'sesh000001'),
	('s000000001', 'sesh000002'),
	('s000000002', 'sesh000002'),
	('s000000001', 'sesh000003'),
	('s000000002', 'sesh000003'),
	('s000000001', 'sesh000004'),
	('s000000002', 'sesh000004'),
	('s000000001', 'sesh000005'),
	('s000000002', 'sesh000005'),
	('s000000001', 'sesh000006'),
	('s000000002', 'sesh000006'),
	('s000000001', 'sesh000007'),
	('s000000002', 'sesh000007'),
	('s000000001', 'sesh000008'),
	('s000000002', 'sesh000008'),
	('s000000001', 'sesh000009'),
	('s000000002', 'sesh000009'),
	('s000000001', 'sesh000010'),
	('s000000002', 'sesh000010'),
	('s000000001', 'sesh000011'),
	('s000000002', 'sesh000011'),
	('s000000001', 'sesh000012'),
	('s000000002', 'sesh000012'),
	('s000000001', 'sesh000013'),
	('s000000002', 'sesh000013'),
	('s000000001', 'sesh000014'),
	('s000000002', 'sesh000014'),
	('s000000001', 'sesh000015'),
	('s000000002', 'sesh000015'),
	('s000000001', 'sesh000016'),
	('s000000002', 'sesh000016'),
	('s000000001', 'sesh000017'),
	('s000000002', 'sesh000017'),
	('s000000001', 'sesh000018'),
	('s000000002', 'sesh000018'),
	('s000000001', 'sesh000019'),
	('s000000002', 'sesh000019'),
	('s000000001', 'sesh000020'),
	('s000000002', 'sesh000020'),
	('s000000001', 'sesh000021'),
	('s000000002', 'sesh000021'),
	('s000000001', 'sesh000022'),
	('s000000002', 'sesh000022'),
	('s000000001', 'sesh000023'),
	('s000000002', 'sesh000023'),
	('s000000001', 'sesh000024'),
	('s000000002', 'sesh000024'),
	('s000000001', 'sesh000025'),
	('s000000002', 'sesh000025'),
	('s000000001', 'sesh000026'),
	('s000000002', 'sesh000026'),
	('s000000001', 'sesh000027'),
	('s000000002', 'sesh000027'),
	('s000000001', 'sesh000028'),
	('s000000002', 'sesh000028'),
	('s000000001', 'sesh000029'),
	('s000000002', 'sesh000029'),
	('s000000001', 'sesh000030'),
	('s000000002', 'sesh000030'),
	('s000000001', 'sesh000031'),
	('s000000002', 'sesh000031'),
	('s000000001', 'sesh000032'),
	('s000000002', 'sesh000032'),
	('s000000001', 'sesh000033'),
	('s000000002', 'sesh000033'),
	('s000000001', 'sesh000034'),
	('s000000002', 'sesh000034'),
	('s000000001', 'sesh000035'),
	('s000000002', 'sesh000035'),
	('s000000001', 'sesh000036'),
	('s000000002', 'sesh000036'),
	('s000000001', 'sesh000037'),
	('s000000002', 'sesh000037'),
	('s000000001', 'sesh000038'),
	('s000000002', 'sesh000038'),
	('s000000001', 'sesh000039'),
	('s000000002', 'sesh000039'),
	('s000000001', 'sesh000040'),
	('s000000002', 'sesh000040'),
	('s000000001', 'sesh000041'),
	('s000000002', 'sesh000041'),
	('s000000001', 'sesh000042'),
	('s000000002', 'sesh000042'),
	('s000000001', 'sesh000043'),
	('s000000002', 'sesh000043'),
	('s000000001', 'sesh000044'),
	('s000000002', 'sesh000044'),
	('s000000001', 'sesh000045'),
	('s000000002', 'sesh000045'),
	('s000000001', 'sesh000046'),
	('s000000002', 'sesh000046'),
	('s000000001', 'sesh000047'),
	('s000000002', 'sesh000047'),
	('s000000001', 'sesh000048'),
	('s000000002', 'sesh000048'),
	('s000000001', 'sesh000049'),
	('s000000002', 'sesh000049'),
	('s000000001', 'sesh000050'),
	('s000000002', 'sesh000050'),
	('s000000001', 'sesh000051'),
	('s000000002', 'sesh000051'),
	('s000000001', 'sesh000052'),
	('s000000002', 'sesh000052'),
	('s000000001', 'sesh000053'),
	('s000000002', 'sesh000053'),
	('s000000001', 'sesh000054'),
	('s000000002', 'sesh000054'),
	('s000000001', 'sesh000055'),
	('s000000002', 'sesh000055'),
	('s000000001', 'sesh000056'),
	('s000000002', 'sesh000056'),
	('s000000001', 'sesh000057'),
	('s000000002', 'sesh000057'),
	('s000000001', 'sesh000058'),
	('s000000002', 'sesh000058'),
	('s000000001', 'sesh000059'),
	('s000000002', 'sesh000059'),
	('s000000001', 'sesh000060'),
	('s000000002', 'sesh000060'),
	('s000000001', 'sesh000061'),
	('s000000002', 'sesh000061'),
	('s000000001', 'sesh000062'),
	('s000000002', 'sesh000062'),
	('s000000001', 'sesh000063'),
	('s000000002', 'sesh000063'),
	('s000000001', 'sesh000064'),
	('s000000002', 'sesh000064'),
	('s000000001', 'sesh000065'),
	('s000000002', 'sesh000065'),
	('s000000001', 'sesh000066'),
	('s000000002', 'sesh000066'),
	('s000000001', 'sesh000067'),
	('s000000002', 'sesh000067'),
	('s000000001', 'sesh000068'),
	('s000000002', 'sesh000068'),
	('s000000001', 'sesh000069'),
	('s000000002', 'sesh000069'),
	('s000000001', 'sesh000070'),
	('s000000002', 'sesh000070'),
	('s000000001', 'sesh000071'),
	('s000000002', 'sesh000071'),
	('s000000001', 'sesh000072'),
	('s000000002', 'sesh000072'),
	('s000000001', 'sesh000073'),
	('s000000002', 'sesh000073'),
	('s000000001', 'sesh000074'),
	('s000000002', 'sesh000074'),
	('s000000001', 'sesh000075'),
	('s000000002', 'sesh000075'),
	('s000000001', 'sesh000076'),
	('s000000002', 'sesh000076'),
	('s000000001', 'sesh000077'),
	('s000000002', 'sesh000077'),
	('s000000001', 'sesh000078'),
	('s000000002', 'sesh000078'),
	('s000000001', 'sesh000079'),
	('s000000002', 'sesh000079'),
	('s000000001', 'sesh000080'),
	('s000000002', 'sesh000080'),
	('s000000001', 'sesh000081'),
	('s000000002', 'sesh000081'),
	('s000000001', 'sesh000082'),
	('s000000002', 'sesh000082'),
	('s000000001', 'sesh000083'),
	('s000000002', 'sesh000083'),
	('s000000001', 'sesh000084'),
	('s000000002', 'sesh000084'),
	('s000000001', 'sesh000085'),
	('s000000002', 'sesh000085'),
	('s000000001', 'sesh000086'),
	('s000000002', 'sesh000086'),
	('s000000001', 'sesh000087'),
	('s000000002', 'sesh000087'),
	('s000000001', 'sesh000088'),
	('s000000002', 'sesh000088'),
	('s000000001', 'sesh000089'),
	('s000000002', 'sesh000089'),
	('s000000001', 'sesh000090'),
	('s000000002', 'sesh000090'),
	('s000000001', 'sesh000091'),
	('s000000002', 'sesh000091'),
	('s000000001', 'sesh000092'),
	('s000000002', 'sesh000092'),
	('s000000001', 'sesh000093'),
	('s000000002', 'sesh000093'),
	('s000000001', 'sesh000094'),
	('s000000002', 'sesh000094'),
	('s000000001', 'sesh000095'),
	('s000000002', 'sesh000095'),
	('s000000001', 'sesh000096'),
	('s000000002', 'sesh000096'),
	('s000000002', 'sesh000097'),
	('s000000003', 'sesh000097'),
	('s000000002', 'sesh000098'),
	('s000000003', 'sesh000098'),
	('s000000002', 'sesh000099'),
	('s000000003', 'sesh000099'),
	('s000000002', 'sesh000100'),
	('s000000003', 'sesh000100'),
	('s000000002', 'sesh000101'),
	('s000000003', 'sesh000101'),
	('s000000002', 'sesh000102'),
	('s000000003', 'sesh000102'),
	('s000000002', 'sesh000103'),
	('s000000003', 'sesh000103'),
	('s000000002', 'sesh000104'),
	('s000000003', 'sesh000104'),
	('s000000002', 'sesh000105'),
	('s000000003', 'sesh000105'),
	('s000000002', 'sesh000106'),
	('s000000003', 'sesh000106'),
	('s000000002', 'sesh000107'),
	('s000000003', 'sesh000107'),
	('s000000002', 'sesh000108'),
	('s000000003', 'sesh000108'),
	('s000000002', 'sesh000109'),
	('s000000003', 'sesh000109'),
	('s000000002', 'sesh000110'),
	('s000000003', 'sesh000110'),
	('s000000002', 'sesh000111'),
	('s000000003', 'sesh000111'),
	('s000000002', 'sesh000112'),
	('s000000003', 'sesh000112'),
	('s000000002', 'sesh000113'),
	('s000000003', 'sesh000113'),
	('s000000002', 'sesh000114'),
	('s000000003', 'sesh000114'),
	('s000000002', 'sesh000115'),
	('s000000003', 'sesh000115'),
	('s000000002', 'sesh000116'),
	('s000000003', 'sesh000116'),
	('s000000002', 'sesh000117'),
	('s000000003', 'sesh000117'),
	('s000000002', 'sesh000118'),
	('s000000003', 'sesh000118'),
	('s000000002', 'sesh000119'),
	('s000000003', 'sesh000119'),
	('s000000002', 'sesh000120'),
	('s000000003', 'sesh000120'),
	('s000000002', 'sesh000121'),
	('s000000003', 'sesh000121'),
	('s000000002', 'sesh000122'),
	('s000000003', 'sesh000122'),
	('s000000002', 'sesh000123'),
	('s000000003', 'sesh000123'),
	('s000000002', 'sesh000124'),
	('s000000003', 'sesh000124'),
	('s000000002', 'sesh000125'),
	('s000000003', 'sesh000125'),
	('s000000002', 'sesh000126'),
	('s000000003', 'sesh000126'),
	('s000000002', 'sesh000127'),
	('s000000003', 'sesh000127'),
	('s000000002', 'sesh000128'),
	('s000000003', 'sesh000128'),
	('s000000002', 'sesh000129'),
	('s000000003', 'sesh000129'),
	('s000000002', 'sesh000130'),
	('s000000003', 'sesh000130'),
	('s000000002', 'sesh000131'),
	('s000000003', 'sesh000131'),
	('s000000002', 'sesh000132'),
	('s000000003', 'sesh000132'),
	('s000000002', 'sesh000133'),
	('s000000003', 'sesh000133'),
	('s000000002', 'sesh000134'),
	('s000000003', 'sesh000134'),
	('s000000002', 'sesh000135'),
	('s000000003', 'sesh000135'),
	('s000000002', 'sesh000136'),
	('s000000003', 'sesh000136'),
	('s000000002', 'sesh000137'),
	('s000000003', 'sesh000137'),
	('s000000002', 'sesh000138'),
	('s000000003', 'sesh000138'),
	('s000000002', 'sesh000139'),
	('s000000003', 'sesh000139'),
	('s000000002', 'sesh000140'),
	('s000000003', 'sesh000140'),
	('s000000002', 'sesh000141'),
	('s000000003', 'sesh000141'),
	('s000000002', 'sesh000142'),
	('s000000003', 'sesh000142'),
	('s000000002', 'sesh000143'),
	('s000000003', 'sesh000143'),
	('s000000002', 'sesh000144'),
	('s000000003', 'sesh000144'),
	('s000000002', 'sesh000145'),
	('s000000003', 'sesh000145'),
	('s000000002', 'sesh000146'),
	('s000000003', 'sesh000146'),
	('s000000002', 'sesh000147'),
	('s000000003', 'sesh000147'),
	('s000000002', 'sesh000148'),
	('s000000003', 'sesh000148'),
	('s000000002', 'sesh000149'),
	('s000000003', 'sesh000149'),
	('s000000002', 'sesh000150'),
	('s000000003', 'sesh000150'),
	('s000000002', 'sesh000151'),
	('s000000003', 'sesh000151'),
	('s000000002', 'sesh000152'),
	('s000000003', 'sesh000152'),
	('s000000002', 'sesh000153'),
	('s000000003', 'sesh000153'),
	('s000000002', 'sesh000154'),
	('s000000003', 'sesh000154'),
	('s000000002', 'sesh000155'),
	('s000000003', 'sesh000155'),
	('s000000002', 'sesh000156'),
	('s000000003', 'sesh000156'),
	('s000000002', 'sesh000157'),
	('s000000003', 'sesh000157'),
	('s000000002', 'sesh000158'),
	('s000000003', 'sesh000158'),
	('s000000002', 'sesh000159'),
	('s000000003', 'sesh000159'),
	('s000000002', 'sesh000160'),
	('s000000003', 'sesh000160'),
	('s000000002', 'sesh000161'),
	('s000000003', 'sesh000161'),
	('s000000002', 'sesh000162'),
	('s000000003', 'sesh000162'),
	('s000000002', 'sesh000163'),
	('s000000003', 'sesh000163'),
	('s000000002', 'sesh000164'),
	('s000000003', 'sesh000164'),
	('s000000002', 'sesh000165'),
	('s000000003', 'sesh000165'),
	('s000000002', 'sesh000166'),
	('s000000003', 'sesh000166'),
	('s000000002', 'sesh000167'),
	('s000000003', 'sesh000167'),
	('s000000002', 'sesh000168'),
	('s000000003', 'sesh000168'),
	('s000000002', 'sesh000169'),
	('s000000003', 'sesh000169'),
	('s000000002', 'sesh000170'),
	('s000000003', 'sesh000170'),
	('s000000002', 'sesh000171'),
	('s000000003', 'sesh000171'),
	('s000000002', 'sesh000172'),
	('s000000003', 'sesh000172'),
	('s000000002', 'sesh000173'),
	('s000000003', 'sesh000173'),
	('s000000002', 'sesh000174'),
	('s000000003', 'sesh000174'),
	('s000000002', 'sesh000175'),
	('s000000003', 'sesh000175'),
	('s000000002', 'sesh000176'),
	('s000000003', 'sesh000176'),
	('s000000002', 'sesh000177'),
	('s000000003', 'sesh000177'),
	('s000000002', 'sesh000178'),
	('s000000003', 'sesh000178'),
	('s000000002', 'sesh000179'),
	('s000000003', 'sesh000179'),
	('s000000002', 'sesh000180'),
	('s000000003', 'sesh000180'),
	('s000000002', 'sesh000181'),
	('s000000003', 'sesh000181'),
	('s000000002', 'sesh000182'),
	('s000000003', 'sesh000182'),
	('s000000002', 'sesh000183'),
	('s000000003', 'sesh000183'),
	('s000000002', 'sesh000184'),
	('s000000003', 'sesh000184'),
	('s000000002', 'sesh000185'),
	('s000000003', 'sesh000185'),
	('s000000002', 'sesh000186'),
	('s000000003', 'sesh000186'),
	('s000000002', 'sesh000187'),
	('s000000003', 'sesh000187'),
	('s000000002', 'sesh000188'),
	('s000000003', 'sesh000188'),
	('s000000002', 'sesh000189'),
	('s000000003', 'sesh000189'),
	('s000000002', 'sesh000190'),
	('s000000003', 'sesh000190'),
	('s000000002', 'sesh000191'),
	('s000000003', 'sesh000191'),
	('s000000002', 'sesh000192'),
	('s000000003', 'sesh000192');

-- Records of STAFF_CONTACT
INSERT INTO branch_b01.staff_contact (contact_id, staff_id)
VALUES
  (1, 's000000001'),
  (2, 's000000002'),
  (3, 's000000003'),
  (4, 's000000004'),
  (5, 's000000005'),
  (6, 's000000006'),
  (7, 's000000007');

-- Records of STUDENT_CONTACT
INSERT INTO branch_b01.student_contact (contact_id, student_id)
VALUES
  (10, 'sn00000001'),
  (1, 'sn00000002'),
  (12, 'sn00000003'),
  (8, 'sn00000004'),
  (3, 'sn00000005'),
  (11, 'sn00000006');

-- Records of STAFF_OFFICE
INSERT INTO branch_b01.staff_office (room_id, staff_id)
VALUES
  (4,'s000000001'),
  (5,'s000000002'),
  (6,'s000000003'),
  (7,'s000000004'),
  (8,'s000000005'),
  (9,'s000000006'),
  (10,'s000000007');

-- Records of ASSIGNMENT

-- Records of STAFF_ASSIGNMENT

/* UPDATE SEED DATA */
-- Assign random grades to all student assessments
UPDATE branch_b01.student_assessment
SET grade = ROUND(CAST(random() * 100 AS numeric), 2);

-- Update attendance records (randomly) for all sessions that have passed
UPDATE branch_b01.student_session AS ss
SET attendance_record = (
  CASE 
    WHEN random() > 0.5 THEN TRUE
    ELSE FALSE
  END
)
WHERE EXISTS (
  SELECT 1
  FROM branch_b01.session AS s
  WHERE s.session_id = ss.session_id
    AND s.session_date < CURRENT_DATE
);

/* Branch b02 inserts */