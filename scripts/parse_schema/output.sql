CREATE OR REPLACE FUNCTION shared.create_schema(schema_name TEXT)
RETURNS void AS $$
BEGIN
  RAISE NOTICE 'CREATING SCHEMA %', schema_name;

	EXECUTE format('
	CREATE SCHEMA IF NOT EXISTS %I;'
	, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.is_room_available(
	  p_room_id INT,
	  p_requested_time TIME,
	  p_requested_date DATE
	) 
	RETURNS BOOLEAN AS $inner$
	DECLARE
	  room_session_count INT;
	BEGIN
	  IF p_requested_time < ''09:00:00''::TIME OR p_requested_time > ''18:00:00''::TIME THEN
	    RAISE EXCEPTION ''Requested time must be between 09:00 and 18:00'';
	  END IF;
	  IF EXTRACT(DOW FROM p_requested_date) IN (0, 6) THEN  -- 0 = Sunday, 6 = Saturday
	    RAISE EXCEPTION ''Requested date cannot be a weekend'';
	  END IF;
	  SELECT COUNT(*)
	  INTO room_session_count
	  FROM %I.session
	  WHERE 
	    room_id = p_room_id
	    AND session_date = p_requested_date
	    AND (
	      (session_start_time <= p_requested_time AND session_end_time > p_requested_time)  -- requested time overlaps with an ongoing session
	      OR
	      (session_start_time < (p_requested_time + interval ''1 minute'') AND session_end_time >= (p_requested_time + interval ''1 minute''))  -- requested time overlaps with session start time
	    );
	  IF room_session_count > 0 THEN
	    RETURN FALSE;
	  ELSE
	    RETURN TRUE;
	  END IF;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.get_day_available_room_time(
	  p_room_id INT,
	  p_requested_date DATE
	)
	RETURNS SETOF TIME AS $inner$
	DECLARE
	  time_slot_start TIME := ''09:00:00''::TIME;
	  time_slot_end TIME := ''18:00:00''::TIME;
	  slot_interval INTERVAL := ''1 hour'';
	BEGIN
	  FOR time_slot_start IN
	    SELECT time_slot_start + (i * slot_interval) 
	    FROM GENERATE_SERIES(0, (EXTRACT(HOUR FROM time_slot_end - time_slot_start) * 60 / 60) - 1) i
	    WHERE time_slot_start + (i * slot_interval) >= ''09:00:00'' AND time_slot_start + (i * slot_interval) <= ''18:00:00''
	  LOOP
	    IF %I.is_room_available(p_room_id, time_slot_start, p_requested_date) THEN
	      RETURN QUERY SELECT time_slot_start;
	    END IF;
	  END LOOP;
	  RETURN;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.link_module_assessment()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  INSERT INTO %I.assessment (assessment_id, assessment_set_date, assessment_due_date, assessment_set_time, assessment_due_time, assessment_visible)
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
	  staff_mobile VARCHAR(15) NOT NULL UNIQUE
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
	  student_attendance DECIMAL(5, 2) DEFAULT (0.00) NOT NULL,
	  CONSTRAINT valid_percentage CHECK (student_attendance >= 0 AND student_attendance <= 100)
	);'
	, schema_name);

	EXECUTE format('
	CREATE TRIGGER %I_before_student_insert
	BEFORE INSERT ON %I.student
	FOR EACH ROW
	EXECUTE FUNCTION shared.student_email();'
	, schema_name, schema_name);

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
	  assessment_visible BOOLEAN NOT NULL,
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
	  tuition_id INT NOT NULL,
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
	  date_assinged DATE NOT NULL DEFAULT CURRENT_DATE,
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
	  assignment_details TEXT NOT NULL,
	  assignment_start_time TIME NOT NULL,
	  assignment_end_time TIME NOT NULL,
	  assignment_date DATE NOT NULL,
	  CONSTRAINT valid_times CHECK (assignment_start_time < assignment_end_time)
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
	CREATE OR REPLACE VIEW %I.student_attendance AS 
	WITH student_details AS (
	  SELECT 
	    student_id,
	    CONCAT_WS('' '', student_fname, student_lname) AS full_name,
	    student_edu_email AS email,
	    student_attendance
	  FROM %I.student
	)
	SELECT 
	  sd.student_id AS "Student ID",
	  sd.full_name AS "Student Name",
	  sd.email AS "Student Email",
	  sd.student_attendance AS "Attendance %%",
	  CASE 
	    WHEN sd.student_attendance > 95 THEN ''Excellent''
	    WHEN sd.student_attendance > 90 THEN ''Good''
	    WHEN sd.student_attendance > 75 THEN ''Satisfactory''
	    WHEN sd.student_attendance > 51 THEN ''Irregular Attendance''
	    WHEN sd.student_attendance > 10 THEN ''Severly Absent''
	    ELSE ''Persitently Absent''
	  END AS "Attendance Rating"
	FROM student_details AS sd
	ORDER BY "Student ID";'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.module_attendance AS 
	SELECT
	  m.module_id AS "Module ID",
	  shm.module_name AS "Module Name",
	  STRING_AGG(DISTINCT c.course_id, '', '') AS "Modules Courses",
	  ROUND(
	    AVG(
	      CASE
	        WHEN total_students > 0 THEN (attending_students * 100.0) / total_students
	        ELSE 0
	      END
	    ), 2
	  ) AS "Module Attendance %%"
	FROM 
	  %I.module AS m
	  JOIN shared.module AS shm USING (module_id)
	  JOIN %I.session AS ses USING (module_id)
	  LEFT JOIN (
	    SELECT
	      session_id,
	      COUNT(*) AS total_students,
	      SUM(CASE WHEN attendance_record THEN 1 ELSE 0 END) AS attending_students
	    FROM %I.student_session
	    GROUP BY session_id
	  ) AS ss_stats ON ses.session_id = ss_stats.session_id
	  JOIN %I.course_module AS cm USING (module_id)
	  JOIN shared.course AS c USING (course_id)
	WHERE 
	  ses.session_date < CURRENT_DATE 
	  OR (ses.session_date = CURRENT_DATE AND ses.session_end_time < CURRENT_TIME)
	GROUP BY "Module ID", "Module Name";'
	, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.course_attendance AS 
	SELECT
	  c.course_id AS "Course ID",
	  shc.course_name AS "Course Name",
	  CONCAT_WS('' '', stf.staff_fname, stf.staff_lname) AS "Course Coordinator",
	  ROUND(AVG(ma."Module Attendance %%"), 2) AS "Course Attendance %%"
	FROM 
	  %I.course AS c
	  JOIN %I.course_module AS cm USING (course_id)
	  JOIN %I.module_attendance AS ma ON cm.module_id = ma."Module ID"
	  JOIN shared.course AS shc USING (course_id)
	  JOIN %I.staff AS stf USING (staff_id)
	GROUP BY "Course ID", "Course Name", "Course Coordinator";'
	, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.unpaid_tuition AS
	WITH tuition_summary AS (
	  SELECT
	    st.student_id,
	    STRING_AGG(t.tuition_id::TEXT, '', '') AS tuition_ids,
	    SUM(t.tuition_amount) AS total_tuition,
	    SUM(t.tuition_paid) AS total_paid,
	    SUM(t.tuition_amount) - SUM(t.tuition_paid) AS total_tuition_remaining,
	    ROUND(
	      100 - ((SUM(t.tuition_paid) / NULLIF(SUM(t.tuition_amount), 0)) * 100),
	      2
	    ) AS overall_remaining_percentage,
	    MIN(t.tuition_deadline) AS closest_tuition_deadline
	  FROM
	    %I.student_tuition AS st
	    JOIN %I.tuition AS t ON st.tuition_id = t.tuition_id
	  WHERE
	    t.tuition_deadline < CURRENT_DATE
	    AND (t.tuition_amount - t.tuition_paid) > 0
	  GROUP BY
	    st.student_id
	)
	SELECT
	  ts.student_id AS "Student ID",
	  CONCAT_WS('' '', 
	    s.student_fname, 
	    CONCAT(LEFT(s.student_lname, 1), REPEAT(''*'', LENGTH(s.student_lname) - 1))
	  ) AS "Masked Student Name",
	  ts.tuition_ids AS "Tuition IDs",
	  ts.total_tuition AS "Total Tuition",
	  ts.total_paid AS "Total Paid",
	  ts.total_tuition_remaining AS "Total Tuition Remaining",
	  ts.overall_remaining_percentage AS "Overall Remaining Percentage %%",
	  ts.closest_tuition_deadline AS "Closest Tuition Deadline",
	  CASE
	    WHEN ts.overall_remaining_percentage >= 75 THEN ''Critical''
	    WHEN ts.overall_remaining_percentage >= 50 THEN ''Warning''
	    ELSE ''Low''
	  END AS "Risk Level"
	FROM
	  tuition_summary AS ts
	  JOIN %I.student AS s ON ts.student_id = s.student_id
	ORDER BY
	  ts.total_tuition_remaining DESC,
	  ts.closest_tuition_deadline;'
	, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.room_session_times AS
	SELECT 
	  r.room_id AS "Room ID",
	  r.room_alt_name AS "Room Name",
	  rt.type_name AS "Room Type",
	  s.session_start_time AS "Session Start Time",
	  s.session_end_time AS "Session End Time",
	  s.session_date AS "Session Date"
	FROM 
	  %I.session AS s
	  JOIN %I.room AS r USING (room_id)
	  JOIN shared.room_type AS rt USING (room_type_id)
	WHERE 
	  s.session_date > CURRENT_DATE
	  OR (s.session_date = CURRENT_DATE AND s.session_start_time > CURRENT_TIME) 
	ORDER BY r.room_id, s.session_date, s.session_start_time;'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.low_performing_students AS
	SELECT 
	  sa."Student ID",
	  sa."Student Name",
	  sa."Student Email",
	  sa."Attendance %%",
	  sa."Attendance Rating",
	  STRING_AGG(
	    CONCAT(c.course_id, '' ('', c.culmative_average, ''%%)''),
	    '', ''
	  ) AS "Courses Failing"
	FROM 
	  %I.student_attendance AS sa
	  LEFT JOIN %I.student_course AS c ON sa."Student ID" = c.student_id
	WHERE 
	  sa."Attendance %%" < 80
	  AND c.culmative_average < 40
	GROUP BY   
	  sa."Student ID",
	  sa."Student Name",
	  sa."Student Email",
	  sa."Attendance %%",
	  sa."Attendance Rating";'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.get_staff_sessions AS 
	SELECT 
	  ss.staff_id,
	  sn.session_date,
	  sn.session_start_time,
	  sn.session_end_time
	FROM
	  %I.staff_session AS ss
	  JOIN %I.session AS sn USING(session_id)
	WHERE 
	  sn.session_date > CURRENT_DATE
	  OR (sn.session_date = CURRENT_DATE AND sn.session_start_time < CURRENT_TIME);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.get_staff_assignments AS 
	SELECT 
	  sa.staff_id,
	  a.assignment_date,
	  a.assignment_start_time,
	  a.assignment_end_time
	FROM
	  %I.staff_assignment AS sa
	  JOIN %I.assignment AS a USING(assignment_id)
	WHERE 
	  a.assignment_date > CURRENT_DATE
	  OR (a.assignment_date = CURRENT_DATE AND a.assignment_start_time < CURRENT_TIME);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.staff_busy AS
	SELECT 
	  ss.staff_id,
	  ss.session_date AS busy_date,
	  ss.session_start_time AS start_time,
	  ss.session_end_time AS end_time
	FROM 
	  %I.get_staff_sessions AS ss
	UNION
	SELECT 
	  sa.staff_id,
	  sa.assignment_date AS busy_date,
	  sa.assignment_start_time AS start_time,
	  sa.assignment_end_time AS end_time
	FROM 
	  %I.get_staff_assignments AS sa;'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE OR REPLACE VIEW %I.staff_availability AS
	WITH date_range AS (
	  SELECT 
	    COALESCE(MIN(busy_date), CURRENT_DATE) AS start_date,
	    COALESCE(MAX(busy_date), CURRENT_DATE) AS end_date
	  FROM %I.staff_busy
	),
	teaching_staff AS (
	  SELECT DISTINCT s.staff_id
	  FROM %I.staff AS s
	  JOIN %I.staff_role AS sr ON s.staff_id = sr.staff_id
	  JOIN shared.role r ON sr.role_id = r.role_id
	  WHERE r.role_name IN (''Lecturer'', ''Teaching Assistant'')
	),
	time_slots AS (
	  SELECT 
	    s.staff_id,
	    date_series.date AS available_date,
	    (date_series.date + (''09:00:00''::TIME + (slot.hour * INTERVAL ''1 hour''))) AS slot_timestamp
	  FROM 
	    teaching_staff AS s,
	    date_range AS dr,
	    generate_series(dr.start_date, dr.end_date, ''1 day''::interval) AS date_series(date),
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
	      FROM %I.staff_busy AS sb
	      WHERE sb.staff_id = time_slots.staff_id
	        AND sb.busy_date = time_slots.available_date::DATE
	        AND sb.start_time::TIME < (time_slots.slot_timestamp + INTERVAL ''1 hour'')::TIME 
	        AND sb.end_time::TIME > time_slots.slot_timestamp::TIME
	    ) AS is_available
	  FROM time_slots
	)
	SELECT 
	  s.staff_id AS "Staff ID",
	  CONCAT_WS('' '', s.staff_title, s.staff_fname, s.staff_lname) AS "Staff Name",
	  LEFT(as_grouped.available_date::TEXT, 10) AS "Date",
	  STRING_AGG(
	    to_char(as_grouped.slot_timestamp, ''HH24:MI''),
	    '', '' ORDER BY as_grouped.slot_timestamp
	  ) AS "Available Times"
	FROM 
	  %I.staff AS s
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
	  as_grouped.available_date;'
	, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	GRANT SELECT ON ALL TABLES IN SCHEMA %I TO student_role;
	REVOKE SELECT ON %I.staff,
	                 %I.staff_role,
	                 %I.staff_department,
	                 %I.staff_session,
	                 %I.staff_contact,
	                 %I.student_contact,
	                 %I.assignment,
	                 %I.staff_assignment
	FROM student_role;'
	, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	GRANT SELECT ON %I.staff,
	                %I.staff_role,
	                %I.staff_department,
	                %I.assignment,
	                %I.staff_assignment,
	                %I.room,
	                %I.building,
	                %I.room_facility
	TO staff_role;'
	, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	GRANT SELECT, UPDATE ON %I.staff_session,
	                         %I.session,
	                         %I.student_assessment,
	                         %I.student_module,
	                         %I.student_course,
	                         %I.assessment
	TO teaching_staff_role;'
	, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	GRANT SELECT ON %I.course,
	                %I.department_course,
	                %I.module,
	                %I.course_module
	TO teaching_staff_role;'
	, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO admin_staff_role;'
	, schema_name);

	EXECUTE format('
	GRANT SELECT ON %I.student_attendance,
	                %I.module_attendance,
	                %I.course_attendance,
	                %I.unpaid_tuition,
	                %I.room_session_times,
	                %I.low_performing_students,
	                %I.get_staff_sessions,
	                %I.get_staff_assignments,
	                %I.staff_busy,
	                %I.staff_availability
	TO admin_staff_role;'
	, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	GRANT SELECT ON %I.module_attendance,
	                %I.course_attendance,
	                %I.room_session_times,
	                %I.get_staff_sessions,
	                %I.get_staff_assignments
	TO teaching_staff_role;'
	, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.staff ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_access_policy
	ON %I.staff
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.staff_role ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_role_access_policy
	ON %I.staff_role
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.course ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_course_access_policy
	ON %I.course
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_course_access_policy
	ON %I.course
	FOR SELECT
	USING (
	  course_id IN (
	    SELECT course_id
	    FROM %I.student_course 
	    WHERE student_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.department_course ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_department_course_access_policy
	ON %I.course
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_department_course_access_policy
	ON %I.department_course
	FOR SELECT
	USING (
	  course_id IN (
	    SELECT course_id
	    FROM %I.student_course 
	    WHERE student_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.module ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_module_access_policy
	ON %I.module
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_module_access_policy
	ON %I.module
	FOR SELECT
	USING (
	  module_id IN (
	    SELECT module_id
	    FROM %I.student_module
	    WHERE student_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.course_module ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_course_module_access_policy
	ON %I.course_module
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_course_module_access_policy
	ON %I.course_module
	FOR SELECT
	USING (
	  module_id IN (
	    SELECT module_id
	    FROM %I.student_module
	    WHERE student_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.student ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_access_policy
	ON %I.student
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.student_course ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_course_access_policy
	ON %I.student_course
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_student_course_access_policy
	ON %I.student_course
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.student_module ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_module_access_policy
	ON %I.student_module
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_student_module_access_policy
	ON %I.student_module
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.assessment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_assessment_access_policy
	ON %I.assessment
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_assessment_access_policy_student
	ON %I.assessment
	FOR SELECT
	USING (
	  assessment_id IN (
	    SELECT assessment_id
	    FROM %I.student_assessment
	    WHERE student_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND assessment_visible = TRUE
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.student_assessment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_assessment_access_policy
	ON %I.student_assessment
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	  AND assessment_id IN (
	    SELECT assessment_id
	    FROM %I.assessment 
	    WHERE assessment_visible = TRUE
	  )
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_student_assessment_access_policy
	ON %I.student_assessment
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.tuition ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_tuition_access_policy
	ON %I.tuition
	FOR SELECT
	USING (
	  tuition_id IN (
	    SELECT t.tuition_id
	    FROM 
	      %I.student_tuition AS st
	      JOIN %I.tuition AS t USING (tuition_id)
	    WHERE st.student_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.student_tuition ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_tuition_access_policy
	ON %I.student_tuition
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.tuition_payment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_tuition_payment_access_policy
	ON %I.tuition_payment
	FOR SELECT
	USING (
	  tuition_payment_id IN (
	    SELECT tp.tuition_payment_id
	    FROM 
	      %I.student_tuition AS st
	      JOIN %I.tuition AS t USING (tuition_id)
	      JOIN %I.tuition_payment AS tp USING (tuition_id)
	    WHERE st.student_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.staff_department ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_department_access_policy
	ON %I.staff_department
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.building ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_building_access_policy
	ON %I.building
	FOR ALL
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  OR pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.room ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_room_access_policy
	ON %I.room
	FOR ALL
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  OR pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.room_facility ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_room_facility_access_policy
	ON %I.room_facility
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.session ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_session_access_policy_staff
	ON %I.session
	FOR SELECT
	USING (
	  session_id IN (
	    SELECT session_id
	    FROM %I.staff_session
	    WHERE staff_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_session_access_policy_student
	ON %I.session
	FOR SELECT
	USING (
	  session_id IN (
	    SELECT session_id
	    FROM %I.student_session
	    WHERE student_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.staff_session ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_session_access_policy
	ON %I.staff_session
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.student_session ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_student_session_access_policy
	ON %I.student_session
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_teaching_student_session_access_policy
	ON %I.student_session
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.staff_contact ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_contact_access_policy
	ON %I.staff_contact
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.staff_office ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_office_access_policy
	ON %I.staff_office
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.assignment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_assignment_access_policy
	ON %I.assignment
	FOR SELECT
	USING (
	  assignment_id IN (
	    SELECT assignment_id 
	    FROM %I.staff_assignment
	    WHERE staff_id = CURRENT_USER
	  )
	  AND pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	);'
	, schema_name, schema_name, schema_name);

	EXECUTE format('
	ALTER TABLE %I.staff_assignment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	EXECUTE format('
	CREATE POLICY %I_staff_assignment_access_policy
	ON %I.staff_assignment
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);
END; 
$$ LANGUAGE plpgsql;