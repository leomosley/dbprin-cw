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

-- Function to create student_edu_email before insert on student
CREATE OR REPLACE FUNCTION shared.student_email()
RETURNS TRIGGER AS $$
BEGIN
  RAISE NOTICE 'CREATING STUDENT EDU EMAIL %', NEW.student_id;
  NEW.student_edu_email := CONCAT(NEW.student_id, '@ses.edu.org');

  IF NEW.student_personal_email IS NOT NULL THEN 
    NEW.student_personal_email := LOWER(NEW.student_personal_email);
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

-- Function to retrieve data about attendance in each branch
CREATE OR REPLACE FUNCTION shared.analyse_branch_attendance()
RETURNS TABLE (
  branch_id CHAR(3),
  avg_student_attendance NUMERIC,
  avg_module_attendance NUMERIC,
  avg_course_attendance NUMERIC,
  top_module_name VARCHAR(50),
  top_module_attendance NUMERIC,
  lowest_module_name VARCHAR(50),
  lowest_module_attendance NUMERIC,
  top_course_name VARCHAR(50),
  top_course_attendance NUMERIC,
  lowest_course_name VARCHAR(50),
  lowest_course_attendance NUMERIC
) AS 
$$
DECLARE
  branch RECORD;
  schema_name TEXT;
  result RECORD;
BEGIN
  FOR branch IN 
    SELECT b.branch_id FROM shared.branch AS b
  LOOP
    schema_name := CONCAT('branch_', branch.branch_id);

    EXECUTE format('
    SELECT
      AVG(s.student_attendance) AS avg_student_attendance,
      AVG(ma."Module Attendance %%") AS avg_module_attendance,
      AVG(ca."Course Attendance %%") AS avg_course_attendance,
      (
        SELECT ma."Module Name"
        FROM %I.module_attendance AS ma
        ORDER BY ma."Module Attendance %%" DESC LIMIT 1
      ) AS top_module_name,
      (
        SELECT ma."Module Attendance %%"
        FROM %I.module_attendance AS ma
        ORDER BY ma."Module Attendance %%" DESC LIMIT 1
      ) AS top_module_attendance,
      (
        SELECT ma."Module Name"
        FROM %I.module_attendance AS ma
        ORDER BY ma."Module Attendance %%" ASC LIMIT 1
      ) AS lowest_module_name,
      (
        SELECT ma."Module Attendance %%"
        FROM %I.module_attendance AS ma
        ORDER BY ma."Module Attendance %%" ASC LIMIT 1
      ) AS lowest_module_attendance,
      (
        SELECT ca."Course Name"
        FROM %I.course_attendance AS ca
        ORDER BY ca."Course Attendance %%" DESC LIMIT 1
      ) AS top_course_name,
      (
        SELECT ca."Course Attendance %%"
        FROM %I.course_attendance AS ca
        ORDER BY ca."Course Attendance %%" DESC LIMIT 1
      ) AS top_course_attendance,
      (
        SELECT ca."Course Name"
        FROM %I.course_attendance AS ca
        ORDER BY ca."Course Attendance %%" ASC LIMIT 1
      ) AS lowest_course_name,
      (
        SELECT ca."Course Attendance %%"
        FROM %I.course_attendance AS ca
        ORDER BY ca."Course Attendance %%" ASC LIMIT 1
      ) AS lowest_course_attendance
    FROM 
      %I.student AS s, 
      %I.module_attendance AS ma, 
      %I.course_attendance AS ca
    ', schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name)
    INTO result;

    RETURN QUERY SELECT 
      branch.branch_id,
      result.avg_student_attendance,
      result.avg_module_attendance,
      result.avg_course_attendance,
      result.top_module_name,
      result.top_module_attendance,
      result.lowest_module_name,
      result.lowest_module_attendance,
      result.top_course_name,
      result.top_course_attendance,
      result.lowest_course_name,
      result.lowest_course_attendance;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to retrieive information about the number of students in each course at each branch
CREATE OR REPLACE FUNCTION shared.count_student_course()
RETURNS TABLE (
  branch_id CHAR(3),
  course_id CHAR(7),
  count BIGINT
) AS 
$$
DECLARE
  branch RECORD;
  schema_name TEXT;
  result RECORD;
BEGIN
  FOR branch IN 
    SELECT b.branch_id FROM shared.branch AS b
  LOOP
    schema_name := CONCAT('branch_', branch.branch_id);

    FOR result IN EXECUTE format('
      SELECT
        c.course_id,
        COUNT(sc.course_id) AS count
      FROM 
        %I.course AS c
        JOIN %I.student_course AS sc USING (course_id)
      GROUP BY c.course_id
    ', schema_name, schema_name)
    LOOP
      RETURN QUERY SELECT 
        branch.branch_id,
        result.course_id,
        result.count;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to retrieive information about students with lower performance in each branch
CREATE OR REPLACE FUNCTION shared.get_all_low_performing_students()
RETURNS TABLE (
  branch_id TEXT,
  student_id CHAR(10),
  name TEXT,
  email CHAR(22),
  attendance DECIMAL(5, 2),
  attendance_rating TEXT,
  courses_failing TEXT
) AS 
$$
DECLARE
  branch RECORD;
  schema_name TEXT;
BEGIN
  FOR branch IN 
    SELECT b.branch_id FROM shared.branch AS b
  LOOP
    schema_name := CONCAT('branch_', branch.branch_id);

    RETURN QUERY EXECUTE format('
      SELECT
        %L AS branch_id,
        "Student ID" AS student_id,
        "Student Name" AS name,
        "Student Email" AS email,
        "Attendance %%"::DECIMAL(5, 2) AS attendance,
        "Attendance Rating" AS attendance_rating,
        "Courses Failing" AS courses_failing
      FROM %I.low_performing_students
    ', branch.branch_id, schema_name);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to dynamically create schema
CREATE OR REPLACE FUNCTION shared.create_schema(schema_name TEXT)
RETURNS void AS $$
BEGIN
  RAISE NOTICE 'CREATING SCHEMA %', schema_name;

	RAISE NOTICE 'CREATING %', '%;';
	EXECUTE format('
	CREATE SCHEMA IF NOT EXISTS %I;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%.is_room_available(';
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

	RAISE NOTICE 'CREATING %', '%.get_day_available_room_time(';
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

	RAISE NOTICE 'CREATING %', '%.link_module_assessment()';
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

	RAISE NOTICE 'CREATING %', '%.link_students_to_assessment()';
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

	RAISE NOTICE 'CREATING %', '%.update_tuition_after_payment()$inner$';
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

	RAISE NOTICE 'CREATING %', '%.link_students_to_session()';
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

	RAISE NOTICE 'CREATING %', '%.link_students_to_module()';
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

	RAISE NOTICE 'CREATING %', '%.update_module_grade()$inner$';
	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.update_module_grade() RETURNS TRIGGER AS $inner$ BEGIN
	  UPDATE %I.student_module AS sm
	  SET 
	    module_grade = (
	      SELECT ROUND(COALESCE(SUM(sa.grade * (a.assessment_weighting / 100)), 0), 2)
	      FROM %I.student_assessment AS sa
	      JOIN shared.assessment AS a ON sa.assessment_id = a.assessment_id
	      WHERE sa.student_id = NEW.student_id AND a.module_id = sm.module_id
	    ),
	    passed = (
	      SELECT CASE
	        WHEN COALESCE(SUM(sa.grade * (a.assessment_weighting / 100)), 0) >= 40 THEN TRUE
	        ELSE FALSE
	      END
	      FROM %I.student_assessment AS sa
	      JOIN shared.assessment AS a ON sa.assessment_id = a.assessment_id
	      WHERE sa.student_id = NEW.student_id AND a.module_id = sm.module_id
	    )
	  WHERE sm.student_id = NEW.student_id
	    AND sm.module_id = (
	      SELECT module_id
	      FROM shared.assessment
	      WHERE assessment_id = NEW.assessment_id
	    );
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.update_course_grade()$inner$';
	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.update_course_grade() RETURNS TRIGGER AS $inner$ BEGIN
	  UPDATE %I.student_course AS sc
	  SET 
	    culmative_average = (
	      SELECT ROUND(COALESCE(AVG(sm.module_grade), 0), 2)
	      FROM %I.student_module AS sm
	      JOIN %I.course_module AS cm ON sm.module_id = cm.module_id
	      WHERE sm.student_id = NEW.student_id AND cm.course_id = sc.course_id
	    )
	  WHERE sc.student_id = NEW.student_id
	    AND sc.course_id = (
	      SELECT course_id
	      FROM %I.course_module
	      WHERE module_id = NEW.module_id
	    );
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.update_student_attendance()';
	EXECUTE format('
	CREATE OR REPLACE FUNCTION %I.update_student_attendance()
	RETURNS TRIGGER AS $inner$
	BEGIN
	  UPDATE %I.student AS s
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
	  WHERE s.student_id = NEW.student_id;
	  RETURN NEW;
	END;
	$inner$ LANGUAGE plpgsql;'
	, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff(';
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

	RAISE NOTICE 'CREATING %', '%_before_staff_insert';
	EXECUTE format('
	CREATE TRIGGER %I_before_staff_insert
	BEFORE INSERT ON %I.staff
	FOR EACH ROW
	EXECUTE FUNCTION shared.validate_staff();'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_trigger_create_student_user';
	EXECUTE format('
	CREATE TRIGGER %I_trigger_create_student_user
	AFTER INSERT ON %I.staff
	FOR EACH ROW
	EXECUTE FUNCTION shared.create_staff_user();'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_unique_staff_personal_email%.staff((staff_personal_email));';
	EXECUTE format('
	CREATE UNIQUE INDEX %I_idx_unique_staff_personal_email ON %I.staff (LOWER(staff_personal_email));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff_role(';
	EXECUTE format('
	CREATE TABLE %I.staff_role (
	  staff_id CHAR(10) NOT NULL,
	  role_id INT NOT NULL,
	  PRIMARY KEY (staff_id, role_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id),
	  FOREIGN KEY (role_id) REFERENCES shared.role (role_id)
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_trigger_grant_staff_roles';
	EXECUTE format('
	CREATE TRIGGER %I_trigger_grant_staff_roles
	AFTER INSERT OR UPDATE ON %I.staff_role
	FOR EACH ROW
	EXECUTE FUNCTION shared.grant_staff_roles();'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_trigger_revoke_roles';
	EXECUTE format('
	CREATE TRIGGER %I_trigger_revoke_roles
	AFTER DELETE OR UPDATE ON %I.staff_role
	FOR EACH ROW
	EXECUTE FUNCTION shared.revoke_staff_roles();'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.department(';
	EXECUTE format('
	CREATE TABLE %I.department (
	  dep_id CHAR(7) NOT NULL,
	  staff_id CHAR(10) NOT NULL,
	  PRIMARY KEY (dep_id),
	  FOREIGN KEY (dep_id) REFERENCES shared.department (dep_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id)
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.course(';
	EXECUTE format('
	CREATE TABLE %I.course (
	  course_id CHAR(7) NOT NULL,
	  staff_id CHAR(10) NOT NULL,
	  PRIMARY KEY (course_id),
	  FOREIGN KEY (course_id) REFERENCES shared.course (course_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id)
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_course_attendance%.course(course_id);';
	EXECUTE format('
	CREATE INDEX %I_idx_course_attendance ON %I.course (course_id);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.department_course(';
	EXECUTE format('
	CREATE TABLE %I.department_course (
	  dep_id CHAR(7) NOT NULL,
	  course_id CHAR(7) NOT NULL,
	  PRIMARY KEY (dep_id, course_id),
	  FOREIGN KEY (dep_id) REFERENCES %I.department (dep_id),
	  FOREIGN KEY (course_id) REFERENCES %I.course (course_id)
	);'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.module(';
	EXECUTE format('
	CREATE TABLE %I.module (
	  module_id CHAR(7) NOT NULL,
	  PRIMARY KEY (module_id),
	  FOREIGN KEY (module_id) REFERENCES shared.module (module_id)
	);'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_module_id%.module(module_id);';
	EXECUTE format('
	CREATE INDEX %I_idx_module_id ON %I.module (module_id);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_module_attendance%.module(module_id);';
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

	RAISE NOTICE 'CREATING %', '%_idx_course_module_combined%.course_module(course_id,module_id);';
	EXECUTE format('
	CREATE INDEX %I_idx_course_module_combined ON %I.course_module (course_id, module_id);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student(';
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

	RAISE NOTICE 'CREATING %', '%_before_student_insert';
	EXECUTE format('
	CREATE TRIGGER %I_before_student_insert
	BEFORE INSERT ON %I.student
	FOR EACH ROW
	EXECUTE FUNCTION shared.student_email();'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_trigger_create_student_user';
	EXECUTE format('
	CREATE TRIGGER %I_trigger_create_student_user
	AFTER INSERT ON %I.student
	FOR EACH ROW
	EXECUTE FUNCTION shared.create_student_user();'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_unique_student_personal_email%.student((student_personal_email));';
	EXECUTE format('
	CREATE UNIQUE INDEX %I_idx_unique_student_personal_email ON %I.student (LOWER(student_personal_email));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_student_id%.student(student_id);';
	EXECUTE format('
	CREATE INDEX %I_idx_student_id ON %I.student (student_id);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_student_attendance%.student(student_attendance);';
	EXECUTE format('
	CREATE INDEX %I_idx_student_attendance ON %I.student (student_attendance);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_course(';
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

	RAISE NOTICE 'CREATING %', '%.student_module(';
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
	  CONSTRAINT valid_grade_percentage CHECK (module_grade >= 0 AND module_grade <= 100)
	);'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_student_module_combined%.student_module(student_id,module_id);';
	EXECUTE format('
	CREATE INDEX %I_idx_student_module_combined ON %I.student_module (student_id, module_id);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_after_insert_assessment';
	EXECUTE format('
	CREATE TRIGGER %I_after_insert_assessment
	AFTER INSERT ON %I.student_module
	FOR EACH ROW
	EXECUTE FUNCTION %I.link_students_to_assessment();'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_assessment_update';
	EXECUTE format('
	CREATE TRIGGER %I_student_assessment_update
	AFTER UPDATE ON %I.student_module
	FOR EACH ROW
	EXECUTE FUNCTION %I.update_course_grade();'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.assessment(';
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

	RAISE NOTICE 'CREATING %', '%_after_insert_module';
	EXECUTE format('
	CREATE TRIGGER %I_after_insert_module
	AFTER INSERT ON %I.module
	FOR EACH ROW
	EXECUTE FUNCTION %I.link_module_assessment();'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_assessment(';
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

	RAISE NOTICE 'CREATING %', '%_student_assessment_update';
	EXECUTE format('
	CREATE TRIGGER %I_student_assessment_update
	AFTER UPDATE ON %I.student_assessment
	FOR EACH ROW
	EXECUTE FUNCTION %I.update_module_grade();'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.tuition(';
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

	RAISE NOTICE 'CREATING %', '%.student_tuition(';
	EXECUTE format('
	CREATE TABLE %I.student_tuition (
	  student_id CHAR(10) NOT NULL,
	  tuition_id INT NOT NULL,
	  PRIMARY KEY (student_id, tuition_id),
	  FOREIGN KEY (student_id) REFERENCES %I.student (student_id),
	  FOREIGN KEY (tuition_id) REFERENCES %I.tuition (tuition_id)
	);'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.tuition_payment(';
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

	RAISE NOTICE 'CREATING %', 'after_student_payment_insert';
	EXECUTE format('
	CREATE TRIGGER after_student_payment_insert 
	AFTER INSERT ON %I.tuition_payment 
	FOR EACH ROW 
	EXECUTE FUNCTION %I.update_tuition_after_payment();'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff_department(';
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

	RAISE NOTICE 'CREATING %', '%.building(';
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

	RAISE NOTICE 'CREATING %', '%.room(';
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

	RAISE NOTICE 'CREATING %', '%.room_facility(';
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

	RAISE NOTICE 'CREATING %', '%.session(';
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

	RAISE NOTICE 'CREATING %', '%_idx_session_date_time%.session(session_date,session_start_time);';
	EXECUTE format('
	CREATE INDEX %I_idx_session_date_time ON %I.session (session_date, session_start_time);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff_session(';
	EXECUTE format('
	CREATE TABLE %I.staff_session (
	  staff_id CHAR(10) NOT NULL,
	  session_id CHAR(10) NOT NULL,
	  PRIMARY KEY (staff_id, session_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id),
	  FOREIGN KEY (session_id) REFERENCES %I.session (session_id)
	);'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_session(';
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

	RAISE NOTICE 'CREATING %', '%_idx_student_session_id%.student_session(session_id);';
	EXECUTE format('
	CREATE INDEX %I_idx_student_session_id ON %I.student_session (session_id);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_attendance_record%.student_session(attendance_record);';
	EXECUTE format('
	CREATE INDEX %I_idx_attendance_record ON %I.student_session (attendance_record);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_idx_attendance_record_true%.student_session(session_id,student_id)attendance_record=;';
	EXECUTE format('
	CREATE INDEX %I_idx_attendance_record_true ON %I.student_session (session_id, student_id) WHERE attendance_record = TRUE;'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_after_insert_session_trigger';
	EXECUTE format('
	CREATE TRIGGER %I_after_insert_session_trigger
	AFTER INSERT ON %I.session
	FOR EACH ROW
	EXECUTE FUNCTION %I.link_students_to_session();'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_update_student_attendance_trigger';
	EXECUTE format('
	CREATE TRIGGER %I_update_student_attendance_trigger
	AFTER UPDATE ON %I.student_session
	FOR EACH ROW
	EXECUTE FUNCTION %I.update_student_attendance();'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff_contact(';
	EXECUTE format('
	CREATE TABLE %I.staff_contact (
	  contact_id INT NOT NULL,
	  staff_id CHAR(10) NOT NULL,
	  PRIMARY KEY (contact_id, staff_id),
	  FOREIGN KEY (contact_id) REFERENCES shared.emergency_contact (contact_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id)
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_contact(';
	EXECUTE format('
	CREATE TABLE %I.student_contact (
	  contact_id INT NOT NULL,
	  student_id CHAR(10) NOT NULL,
	  PRIMARY KEY (contact_id, student_id),
	  FOREIGN KEY (contact_id) REFERENCES shared.emergency_contact (contact_id),
	  FOREIGN KEY (student_id) REFERENCES %I.student (student_id)
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff_office(';
	EXECUTE format('
	CREATE TABLE %I.staff_office (
	  room_id INT NOT NULL,
	  staff_id CHAR(10) NOT NULL,
	  PRIMARY KEY (room_id, staff_id),
	  FOREIGN KEY (room_id) REFERENCES %I.room (room_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id)
	);'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.assignment(';
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

	RAISE NOTICE 'CREATING %', '%.staff_assignment(';
	EXECUTE format('
	CREATE TABLE %I.staff_assignment (
	  staff_id CHAR(10) NOT NULL,
	  assignment_id INT NOT NULL,
	  PRIMARY KEY (staff_id, assignment_id),
	  FOREIGN KEY (staff_id) REFERENCES %I.staff (staff_id),
	  FOREIGN KEY (assignment_id) REFERENCES %I.assignment (assignment_id)
	);'
	, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_attendance';
	EXECUTE format('
  CREATE OR REPLACE VIEW %I.student_attendance AS
  SELECT 
    s.student_id AS "Student ID",
    CONCAT_WS('' '', s.student_fname, s.student_lname) AS "Student Name",
    s.student_edu_email AS "Student Email",
    s.student_attendance AS "Attendance %%",
    CASE 
      WHEN s.student_attendance > 95 THEN ''Excellent''
      WHEN s.student_attendance > 90 THEN ''Good''
      WHEN s.student_attendance > 75 THEN ''Satisfactory''
      WHEN s.student_attendance > 51 THEN ''Irregular Attendance''
      WHEN s.student_attendance > 10 THEN ''Severely Absent''
      ELSE ''Persistently Absent''
    END AS "Attendance Rating"
  FROM %I.student AS s
  ORDER BY "Student ID";',
  schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.module_attendance';
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
  GROUP BY "Module ID", "Module Name";',
  schema_name, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.course_attendance';
	EXECUTE format('
  CREATE OR REPLACE VIEW %I.course_attendance AS
  SELECT
    c.course_id AS "Course ID",
    shc.course_name AS "Course Name",
    CONCAT_WS('''' , stf.staff_fname, stf.staff_lname) AS "Course Coordinator",
    ROUND(AVG(ma."Module Attendance %%"), 2) AS "Course Attendance %%"
  FROM 
    %I.course AS c
    JOIN %I.course_module AS cm USING (course_id)
    JOIN %I.module_attendance AS ma ON cm.module_id = ma."Module ID"
    JOIN shared.course AS shc USING (course_id)
    JOIN %I.staff AS stf USING (staff_id)
  GROUP BY "Course ID", "Course Name", "Course Coordinator";',
  schema_name, schema_name, schema_name, schema_name, schema_name);


	RAISE NOTICE 'CREATING %', '%.unpaid_tuition';
	EXECUTE format('
  CREATE OR REPLACE VIEW %I.unpaid_tuition AS
  WITH tuition_summary AS (
    SELECT
      st.student_id,
      STRING_AGG(t.tuition_id::TEXT, '''') AS tuition_ids,
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
    CONCAT_WS('''' , 
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
    ts.closest_tuition_deadline;',
  schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.room_session_times';
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
  ORDER BY r.room_id, s.session_date, s.session_start_time;',
  schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.low_performing_students';
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
    sa."Attendance Rating";',
  schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.get_staff_sessions';
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
    OR (sn.session_date = CURRENT_DATE AND sn.session_start_time < CURRENT_TIME);',
  schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.get_staff_assignments';
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
    OR (a.assignment_date = CURRENT_DATE AND a.assignment_start_time < CURRENT_TIME);',
  schema_name, schema_name, schema_name);


	RAISE NOTICE 'CREATING %', '%.staff_busy';
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
    %I.get_staff_assignments AS sa;',
  schema_name, schema_name, schema_name);


	RAISE NOTICE 'CREATING %', '%.staff_availability';
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
    as_grouped.available_date;',
  schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%student_role;';
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
  FROM student_role;',
  schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff,';
	EXECUTE format('
  GRANT SELECT ON %I.staff,
                 %I.staff_role,
                 %I.staff_department,
                 %I.assignment,
                 %I.staff_assignment,
                 %I.room,
                 %I.building,
                 %I.room_facility
  TO staff_role;',
  schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', ',%.staff_session,';
	EXECUTE format('
  GRANT SELECT, UPDATE ON %I.staff_session,
                          %I.session,
                          %I.student_assessment,
                          %I.student_module,
                          %I.student_course,
                          %I.assessment
  TO teaching_staff_role;',
  schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.course,';
	EXECUTE format('
  GRANT SELECT, UPDATE ON %I.staff_session,
                          %I.session,
                          %I.student_assessment,
                          %I.student_module,
                          %I.student_course,
                          %I.assessment
  TO teaching_staff_role;',
  schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);


	RAISE NOTICE 'CREATING %', ',,,%admin_staff_role;';
	EXECUTE format('
	GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO admin_staff_role;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_attendance,';
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
  TO admin_staff_role;',
  schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.module_attendance,';
	EXECUTE format('
  GRANT SELECT ON %I.module_attendance,
                 %I.course_attendance,
                 %I.room_session_times,
                 %I.get_staff_sessions,
                 %I.get_staff_assignments
  TO teaching_staff_role;',
  schema_name, schema_name, schema_name, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff;';
	EXECUTE format('
	ALTER TABLE %I.staff ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_access_policy
	ON %I.staff
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff_role;';
	EXECUTE format('
	ALTER TABLE %I.staff_role ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_role_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_role_access_policy
	ON %I.staff_role
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.course;';
	EXECUTE format('
	ALTER TABLE %I.course ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_teaching_course_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_course_access_policy
	ON %I.course
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_course_access_policy';
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

	RAISE NOTICE 'CREATING %', '%.department_course;';
	EXECUTE format('
	ALTER TABLE %I.department_course ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_teaching_department_course_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_department_course_access_policy
	ON %I.course
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_department_course_access_policy';
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

	RAISE NOTICE 'CREATING %', '%.module;';
	EXECUTE format('
	ALTER TABLE %I.module ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_teaching_module_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_module_access_policy
	ON %I.module
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_module_access_policy';
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

	RAISE NOTICE 'CREATING %', '%.course_module;';
	EXECUTE format('
	ALTER TABLE %I.course_module ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_teaching_course_module_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_course_module_access_policy
	ON %I.course_module
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_course_module_access_policy';
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

	RAISE NOTICE 'CREATING %', '%.student;';
	EXECUTE format('
	ALTER TABLE %I.student ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_access_policy';
	EXECUTE format('
	CREATE POLICY %I_student_access_policy
	ON %I.student
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_course;';
	EXECUTE format('
	ALTER TABLE %I.student_course ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_course_access_policy';
	EXECUTE format('
	CREATE POLICY %I_student_course_access_policy
	ON %I.student_course
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_teaching_student_course_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_student_course_access_policy
	ON %I.student_course
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_module;';
	EXECUTE format('
	ALTER TABLE %I.student_module ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_module_access_policy';
	EXECUTE format('
	CREATE POLICY %I_student_module_access_policy
	ON %I.student_module
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_teaching_student_module_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_student_module_access_policy
	ON %I.student_module
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.assessment;';
	EXECUTE format('
	ALTER TABLE %I.assessment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_teaching_assessment_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_assessment_access_policy
	ON %I.assessment
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_assessment_access_policy_student';
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

	RAISE NOTICE 'CREATING %', '%.student_assessment;';
	EXECUTE format('
	ALTER TABLE %I.student_assessment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_assessment_access_policy';
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

	RAISE NOTICE 'CREATING %', '%_staff_teaching_student_assessment_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_student_assessment_access_policy
	ON %I.student_assessment
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.tuition;';
	EXECUTE format('
	ALTER TABLE %I.tuition ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_tuition_access_policy';
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

	RAISE NOTICE 'CREATING %', '%.student_tuition;';
	EXECUTE format('
	ALTER TABLE %I.student_tuition ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_tuition_access_policy';
	EXECUTE format('
	CREATE POLICY %I_student_tuition_access_policy
	ON %I.student_tuition
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.tuition_payment;';
	EXECUTE format('
	ALTER TABLE %I.tuition_payment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_tuition_payment_access_policy';
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

	RAISE NOTICE 'CREATING %', '%.staff_department;';
	EXECUTE format('
	ALTER TABLE %I.staff_department ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_department_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_department_access_policy
	ON %I.staff_department
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.building;';
	EXECUTE format('
	ALTER TABLE %I.building ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_building_access_policy';
	EXECUTE format('
	CREATE POLICY %I_building_access_policy
	ON %I.building
	FOR ALL
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  OR pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.room;';
	EXECUTE format('
	ALTER TABLE %I.room ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_room_access_policy';
	EXECUTE format('
	CREATE POLICY %I_room_access_policy
	ON %I.room
	FOR ALL
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  OR pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.room_facility;';
	EXECUTE format('
	ALTER TABLE %I.room_facility ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_room_facility_access_policy';
	EXECUTE format('
	CREATE POLICY %I_room_facility_access_policy
	ON %I.room_facility
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.session;';
	EXECUTE format('
	ALTER TABLE %I.session ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_session_access_policy_staff';
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

	RAISE NOTICE 'CREATING %', '%_session_access_policy_student';
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

	RAISE NOTICE 'CREATING %', '%.staff_session;';
	EXECUTE format('
	ALTER TABLE %I.staff_session ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_session_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_session_access_policy
	ON %I.staff_session
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.student_session;';
	EXECUTE format('
	ALTER TABLE %I.student_session ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_student_session_access_policy';
	EXECUTE format('
	CREATE POLICY %I_student_session_access_policy
	ON %I.student_session
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''student_role'', ''USAGE'')
	  AND student_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_teaching_student_session_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_teaching_student_session_access_policy
	ON %I.student_session
	FOR ALL
	USING (pg_has_role(CURRENT_USER, ''teaching_staff_role'', ''USAGE''));'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff_contact;';
	EXECUTE format('
	ALTER TABLE %I.staff_contact ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_contact_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_contact_access_policy
	ON %I.staff_contact
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.staff_office;';
	EXECUTE format('
	ALTER TABLE %I.staff_office ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_office_access_policy';
	EXECUTE format('
	CREATE POLICY %I_staff_office_access_policy
	ON %I.staff_office
	FOR SELECT
	USING (
	  pg_has_role(CURRENT_USER, ''staff_role'', ''USAGE'')
	  AND staff_id = CURRENT_USER 
	);'
	, schema_name, schema_name);

	RAISE NOTICE 'CREATING %', '%.assignment;';
	EXECUTE format('
	ALTER TABLE %I.assignment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_assignment_access_policy';
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

	RAISE NOTICE 'CREATING %', '%.staff_assignment;';
	EXECUTE format('
	ALTER TABLE %I.staff_assignment ENABLE ROW LEVEL SECURITY;'
	, schema_name);

	RAISE NOTICE 'CREATING %', '%_staff_assignment_access_policy';
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
  branch_addr1 VARCHAR(150) NOT NULL,
  branch_addr2 VARCHAR(150),
  branch_postcode VARCHAR(10) NOT NULL,
  branch_contact_number VARCHAR(15) NOT NULL,
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
  dep_description TEXT
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

/* CREATE SHARED VIEWS */

-- View to show information about attendance for each branch
-- Average student, module, and course attendance 
-- Extremes (worst and best) of module and course attendance
CREATE OR REPLACE VIEW shared.branch_attendance AS
SELECT 
  b.branch_id AS "Branch ID",
  b.branch_name AS "Branch Name",
  CONCAT(ROUND(saba.avg_student_attendance, 2), '%') AS "Average Student Attendance",
  CONCAT(ROUND(saba.avg_module_attendance, 2), '%') AS "Average Module Attendance",
  CONCAT(ROUND(saba.avg_course_attendance, 2), '%') AS "Average Course Attendance",
  CONCAT(
    saba.top_module_name,
    ' (', ROUND(saba.top_module_attendance, 2), '%)'
  ) AS "Best Module Attendance",
  CONCAT(
    saba.lowest_module_name,
    ' (', ROUND(saba.lowest_module_attendance, 2), '%)'
  ) AS "Worst Module Attendance",
  CONCAT(
    saba.top_course_name,
    ' (', ROUND(saba.top_course_attendance, 2), '%)'
  ) AS "Best Course Attendance",
  CONCAT(
    saba.lowest_course_name,
    ' (', ROUND(saba.lowest_course_attendance, 2), '%)'
  ) AS "Worst Course Attendance"
FROM 
  shared.analyse_branch_attendance() AS saba
  JOIN shared.branch AS b USING (branch_id)
ORDER BY b.branch_id;

-- View to show number of students in each course across all branches to show course popularity
CREATE OR REPLACE VIEW shared.course_popularity AS
SELECT
  c.course_id AS "Course ID",
  c.course_name AS "Course Name",
  SUM(css.count) AS "Total Students"
FROM
  shared.course AS c
  JOIN shared.count_student_course() AS css USING (course_id)
GROUP BY "Course ID", "Course Name"
ORDER BY "Total Students" DESC;

-- View to show all low performing students across all branches
CREATE OR REPLACE VIEW shared.branch_low_performing_students AS
WITH lps AS (
  SELECT * 
  FROM shared.get_all_low_performing_students()
)
SELECT 
  lps.branch_id AS "Branch ID",
  bt.total_low_performing_students AS "Branch Total Low Performing Students",
  lps.student_id AS "Student ID",
  lps.name AS "Student Name",
  lps.email AS "Student Email",
  lps.attendance AS "Attendance %",
  lps.attendance_rating AS "Attendance Rating",
  lps.courses_failing AS "Courses Failing"
FROM 
  lps
  JOIN (
    SELECT 
      branch_id, 
      COUNT(*) AS total_low_performing_students
    FROM lps
    GROUP BY branch_id
  ) AS bt USING (branch_id)
ORDER BY 
  "Branch ID",
  "Attendance %";

/* GRANT ACCESS FOR SHARED SCHEMA */

-- Grant SELECT access to all tables in the shared schema except emergency_contact and role
GRANT SELECT ON ALL TABLES IN SCHEMA shared TO student_role;
REVOKE SELECT ON shared.emergency_contact, shared.role FROM student_role;

-- Grant SELECT access to specific tables in the shared schema
GRANT SELECT ON shared.role,
                shared.department,
                shared.room_type,
                shared.facility,
                shared.branch
TO staff_role;

-- Grant all the permissions of staff_role
GRANT staff_role TO teaching_staff_role;

-- Grant SELECT access to all tables in the shared schema except emergency_contact
GRANT SELECT ON ALL TABLES IN SCHEMA shared TO teaching_staff_role;
REVOKE SELECT ON shared.emergency_contact FROM teaching_staff_role;

-- Grant INSERT and UPDATE access to shared.assessment
GRANT INSERT, UPDATE ON shared.assessment TO teaching_staff_role;

-- Grant all the permissions of staff_role and allow it to bypass RLS
GRANT staff_role TO admin_staff_role;
ALTER ROLE admin_staff_role SET row_security = off;

-- Grant SELECT, UPDATE, CREATE, DELETE access to all tables in all schemas
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA shared TO admin_staff_role;

-- Grant SELECT on shared views for admin staff only
GRANT SELECT ON shared.branch_attendance, shared.course_popularity, shared.branch_low_performing_students 
TO admin_staff_role;

/* ENABLE RLS AND CREATE FOR SHARED TABLES */
-- Branch Policy
ALTER TABLE shared.branch ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_branch
ON shared.branch
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_role', 'USAGE') OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE'));

-- Department Policy
ALTER TABLE shared.department ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_department
ON shared.department
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_role', 'USAGE') OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE'));

-- Course Policy
ALTER TABLE shared.course ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_course
ON shared.course
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_teaching_role', 'USAGE') OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE'));

-- Department Course Policy
ALTER TABLE shared.department_course ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_department_course
ON shared.department_course
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_teaching_role', 'USAGE') OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE'));

-- Module Policy
ALTER TABLE shared.module ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_module
ON shared.module
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_teaching_role', 'USAGE') OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE'));

-- Course Module Policy
ALTER TABLE shared.course_module ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_course_module
ON shared.course_module
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_teaching_role', 'USAGE') OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE'));

-- Assessment Policy
ALTER TABLE shared.assessment ENABLE ROW LEVEL SECURITY;

CREATE POLICY staff_access_policy_shared_assessment
ON shared.assessment
FOR ALL
USING (pg_has_role(CURRENT_USER, 'teaching_staff_role', 'USAGE'));

-- Role Policy
ALTER TABLE shared.role ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_role
ON shared.role
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_role', 'USAGE'));

-- Facility Policty
ALTER TABLE shared.facility ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_facilitiy
ON shared.facility
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_role', 'USAGE'));

-- Room Type Policy
ALTER TABLE shared.room_type ENABLE ROW LEVEL SECURITY;

CREATE POLICY access_policy_shared_room_type
ON shared.room_type
FOR ALL
USING (pg_has_role(CURRENT_USER, 'staff_role', 'USAGE') OR pg_has_role(CURRENT_USER, 'student_role', 'USAGE'));

-- Emergency Contact Policy
ALTER TABLE shared.emergency_contact ENABLE ROW LEVEL SECURITY;


-- Records of shared.branch
INSERT INTO shared.branch (branch_name, branch_status, branch_addr1, branch_addr2, branch_postcode, branch_contact_number, branch_email)  VALUES ('SES London', 'Open', '123 High Street', 'Westminster', 'SW1A 1AA', '020 7946 0958', 'london@ses.edu.org');
INSERT INTO shared.branch (branch_name, branch_status, branch_addr1, branch_addr2, branch_postcode, branch_contact_number, branch_email)  VALUES ('SES Manchester', 'Open', '45 Oxford Road', 'Manchester City Centre', 'M1 5QA', '0161 306 6000', 'manchester@ses.edu.org');

-- Records of shared.department
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Mathematics', 'Educational', 'Department of Mathematics');
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Arts', 'Educational', 'Department of Arts');
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Computing', 'Educational', 'Department of Computing');
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Humanities', 'Educational', 'Department of Humanities');
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Science', 'Educational', 'Department of Science');
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Vocational Training', 'Educational', 'Department of Vocational Training');
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Finance', 'Administrative', NULL);
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Facilities and Maintenance', 'Maintenance', NULL);
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('SES Operations', 'Operational', 'Manages the SES operations and infrastructure');
INSERT INTO shared.department (dep_name, dep_type, dep_description)  VALUES ('Human Resources', 'Administrative', NULL);

-- Records of shared.course
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Advanced Calculus', 'A deep dive into calculus, focusing on multivariable calculus and real analysis.', 'A-level Mathematics or equivalent.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Machine Learning', 'An introduction to machine learning algorithms and their mathematical foundations.', 'A-level Mathematics and Programming experience.', 3 );
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Modern Art Techniques', 'Explores various techniques and styles used in modern art, with practical workshops.', 'Portfolio submission required.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Art History and Critique', 'A comprehensive study of art history from antiquity to the present day.', 'A-level History or equivalent.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Software Engineering', 'Focuses on the principles of software design, testing, and project management.', 'A-level Mathematics or equivalent.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Cybersecurity', 'An in-depth look at cybersecurity principles, including threat analysis and defense mechanisms.', 'A-level Mathematics and Programming experience.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Philosophy and Ethics', 'Explores philosophical questions and their relevance to modern ethical issues.', 'A-level English Literature or equivalent.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('World History', 'A study of major historical events and their global impact.', 'A-level History or equivalent.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Biotechnology', 'Covers the principles of biotechnology and its applications in healthcare and agriculture.', 'A-level Biology and Chemistry.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Astrophysics', 'An introduction to the physics of stars, galaxies, and the universe.', 'A-level Mathematics and Physics.', 3);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Culinary Arts', 'Provides training in professional cooking techniques and food safety.', 'Basic GCSEs required.', 2);
INSERT INTO shared.course (course_name, course_description, course_entry_requirements, course_length) VALUES ('Construction Technology', 'Covers modern construction techniques and safety protocols.', 'Basic GCSEs required.', 2);

-- Records of shared.department_course
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000001' , 'c000001');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000001' , 'c000002');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000002' , 'c000003');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000002' , 'c000004');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000003' , 'c000005');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000003' , 'c000006');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000003' , 'c000002');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000004' , 'c000007');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000004' , 'c000008');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000005' , 'c000009');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000005' , 'c000010');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000006' , 'c000011');
INSERT INTO shared.department_course (dep_id, course_id) VALUES ('d000006' , 'c000012');

-- Records of shared.module
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Multivariable Calculus', 'Explores multivariable functions, partial derivatives, and multiple integrals.', 'L7', 20, 'Active', '2024-12-01', 200.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Real Analysis', 'Covers limits, continuity, differentiation, and integration on real number sets.', 'L7', 20, 'Active', '2024-12-01', 180.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Supervised Learning', 'Introduction to supervised learning algorithms and their applications.', 'L4', 20, 'Active', '2024-12-01', 200.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Neural Networks', 'Covers the basics of artificial neural networks and deep learning.', 'L5', 20, 'Active', '2024-12-01', 190.00, 1);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Abstract Painting', 'Hands-on techniques for creating abstract art.', 'L6', 20, 'Active', '2024-12-01', 200.00, 1);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Digital Art Methods', 'Explores the use of digital tools in modern art creation.', 'L5', 20, 'Active', '2024-12-01', 140.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Renaissance Art', 'A study of Renaissance art and its historical significance.', 'L5', 20, 'Active', '2024-12-01', 180.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Contemporary Art Movements', 'Analysis of art movements in the 20th and 21st centuries.', 'L6', 20, 'Active', '2024-12-01', 170.00, 1);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Agile Development', 'Covers principles and practices of Agile development.', 'L5', 20, 'Active', '2024-12-01', 180.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Software Testing', 'Focuses on testing methodologies and quality assurance.', 'L4', 20, 'Active', '2024-12-01', 190.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Cryptography', 'Introduction to cryptographic principles and practices.', 'L4', 20, 'Active', '2024-12-01', 200.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Network Security', 'Focuses on securing computer networks against threats.', 'L4', 20, 'Active', '2024-12-01', 190.00, 1);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Moral Philosophy', 'Explores ethical theories and moral decision-making.', 'L5', 20, 'Active', '2024-12-01', 200.00, 1);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Political Philosophy', 'Analyzes the philosophical foundations of political systems.', 'L5', 20, 'Active', '2024-12-01', 160.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Ancient Civilizations', 'Study of ancient civilizations and their cultural impact.', 'L5', 20, 'Active', '2024-12-01', 170.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Modern Conflicts', 'Examines key conflicts in modern history.', 'L6', 20, 'Active', '2024-12-01', 160.00, 1);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Genetic Engineering', 'Introduction to genetic modification techniques.', 'L4', 20, 'Active', '2024-12-01', 200.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Bioinformatics', 'Covers computational tools for biological data analysis.', 'L6', 20, 'Active', '2024-12-01', 190.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Stellar Physics', 'Study of the physical properties of stars.', 'L4', 20, 'Active', '2024-12-01', 180.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Cosmology', 'Introduction to the study of the universe.', 'L4', 20, 'Active', '2024-12-01', 170.00, 1);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Pastry Techniques', 'Covers the techniques for making pastries and desserts.', 'L5', 20, 'Active', '2024-12-01', 200.00, 1);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Savory Dishes', 'Training in preparation of savory meals.', 'L6', 20, 'Active', '2024-12-01', 160.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Building Materials', 'Study of materials used in modern construction.', 'L5', 20, 'Active', '2024-12-01', 200.00, 2);
INSERT INTO shared.module (module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration) VALUES ('Construction Safety', 'Focus on safety protocols and regulations.', 'L4', 20, 'Active', '2024-12-01', 160.00, 1);

-- Records of shared.course_module
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000001', 'm000001');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000001', 'm000002');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000002', 'm000003');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000002', 'm000004');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000003', 'm000005');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000003', 'm000006');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000004', 'm000007');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000004', 'm000008');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000005', 'm000009');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000005', 'm000010');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000006', 'm000011');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000006', 'm000012');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000007', 'm000013');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000007', 'm000014');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000008', 'm000015');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000008', 'm000016');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000009', 'm000017');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000009', 'm000018');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000010', 'm000019');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000010', 'm000020');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000011', 'm000021');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000011', 'm000022');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000012', 'm000023');
INSERT INTO shared.course_module (course_id, module_id)  VALUES ('c000012', 'm000024');

-- Records of shared.assessment
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000001', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000001', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000001', 'Coursework Project',  NULL, 'Coursework', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000001', 'Essay', NULL, 'Essay', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000001', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000001', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000002', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000002', 'Final Exam',  NULL, 'Exam', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000002', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000002', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000002', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000002', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000003', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000003', 'Final Exam',  NULL, 'Exam', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000003', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000003', 'Essay', NULL, 'Essay', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000003', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000003', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000004', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000004', 'Final Exam',  NULL, 'Exam', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000004', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000004', 'Essay', NULL, 'Essay', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000004', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000004', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000005', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000005', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000005', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000005', 'Essay', NULL, 'Essay', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000005', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000005', 'Presentation', NULL, 'Presentation', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000006', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000006', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000006', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000006', 'Essay', NULL, 'Essay', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000006', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000006', 'Presentation', NULL, 'Presentation', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000007', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000007', 'Final Exam',  NULL, 'Exam', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000007', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000007', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000007', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000007', 'Presentation', NULL, 'Presentation', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000008', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000008', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000008', 'Coursework Project',  NULL, 'Coursework', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000008', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000008', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000008', 'Presentation', NULL, 'Presentation', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000009', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000009', 'Final Exam',  NULL, 'Exam', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000009', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000009', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000009', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000009', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000010', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000010', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000010', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000010', 'Essay', NULL, 'Essay', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000010', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000010', 'Presentation', NULL, 'Presentation', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000011', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000011', 'Final Exam',  NULL, 'Exam', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000011', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000011', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000011', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000011', 'Presentation', NULL, 'Presentation', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000012', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000012', 'Final Exam',  NULL, 'Exam', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000012', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000012', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000012', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000012', 'Presentation', NULL, 'Presentation', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000013', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000013', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000013', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000013', 'Essay', NULL, 'Essay', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000013', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000013', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000014', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000014', 'Final Exam',  NULL, 'Exam', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000014', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000014', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000014', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000014', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000015', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000015', 'Final Exam',  NULL, 'Exam', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000015', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000015', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000015', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000015', 'Presentation', NULL, 'Presentation', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000016', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000016', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000016', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000016', 'Essay', NULL, 'Essay', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000016', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000016', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000017', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000017', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000017', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000017', 'Essay', NULL, 'Essay', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000017', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000017', 'Presentation', NULL, 'Presentation', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000018', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000018', 'Final Exam',  NULL, 'Exam', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000018', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000018', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000018', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000018', 'Presentation', NULL, 'Presentation', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000019', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000019', 'Final Exam',  NULL, 'Exam', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000019', 'Coursework Project',  NULL, 'Coursework', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000019', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000019', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000019', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000020', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000020', 'Final Exam',  NULL, 'Exam', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000020', 'Coursework Project',  NULL, 'Coursework', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000020', 'Essay', NULL, 'Essay', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000020', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000020', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000021', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000021', 'Final Exam',  NULL, 'Exam', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000021', 'Coursework Project',  NULL, 'Coursework', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000021', 'Essay', NULL, 'Essay', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000021', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000021', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000022', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000022', 'Final Exam',  NULL, 'Exam', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000022', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000022', 'Essay', NULL, 'Essay', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000022', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000022', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000023', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000023', 'Final Exam',  NULL, 'Exam', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000023', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000023', 'Essay', NULL, 'Essay', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000023', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000023', 'Presentation', NULL, 'Presentation', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000024', 'General Exam', NULL, 'Exam', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000024', 'Final Exam',  NULL, 'Exam', 30.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000024', 'Coursework Project',  NULL, 'Coursework', 10.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000024', 'Essay', NULL, 'Essay', 50.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000024', 'Research Essay', NULL, 'Essay', 0.00, NULL);
INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment) VALUES ('m000024', 'Presentation', NULL, 'Presentation', 10.00, NULL);

-- Records of shared.role
INSERT INTO shared.role (role_name)  VALUES ('Lecturer');
INSERT INTO shared.role (role_name)  VALUES ('Teaching Assistant');
INSERT INTO shared.role (role_name)  VALUES ('Accountant');
INSERT INTO shared.role (role_name)  VALUES ('Human Resources Manager');
INSERT INTO shared.role (role_name)  VALUES ('Recruiter');
INSERT INTO shared.role (role_name)  VALUES ('IT Support Specialist');
INSERT INTO shared.role (role_name)  VALUES ('Facilities Manager');
INSERT INTO shared.role (role_name)  VALUES ('Security Officer');
INSERT INTO shared.role (role_name)  VALUES ('Library Assistant');
INSERT INTO shared.role (role_name)  VALUES ('Receptionist');
INSERT INTO shared.role (role_name)  VALUES ('Maintenance Technician');
INSERT INTO shared.role (role_name)  VALUES ('Groundskeeper');
INSERT INTO shared.role (role_name)  VALUES ('Admin staff');

-- Records of shared.facility
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (100, 'Desktop Computers');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (20, 'Projectors');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (200, 'Whiteboards');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (5, '3D Printers');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (15, 'Microscopes');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (25, 'Easels');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (30, 'Sound Systems');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (40, 'Keyboards and Musical Instruments');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (10, 'Cooking Stations');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (10, 'Workshop Tools and Machines');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (12, 'Sports Equipment Sets');
INSERT INTO shared.facility (facility_total_quantity, facility_name) VALUES (20, 'Printers and Scanners');

-- Records of shared.room_type
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Lecture Theatre', 'Large room equipped with seating for lectures and presentations.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Seminar Room', 'Medium-sized room designed for seminars, group discussions, and workshops.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Laboratory', 'Room equipped with specialized tools and equipment for experiments and practical sessions.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Computer Lab', 'Room with computers and software for programming, simulations, and digital training.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Art Studio', 'Creative space for art and design activities, equipped with easels and materials.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Music Room', 'Room designed for music practice and lessons, with soundproofing and instruments.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Conference Room', 'Room for formal meetings, discussions, and small conferences.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Library', 'Quiet space with resources for reading, studying, and research.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Cafeteria', 'Dining area for students and staff, serving meals and refreshments.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Sports Hall', 'Indoor facility for physical activities and sports events.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Workshop', 'Room equipped for vocational training, including tools and machinery.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Examination Hall', 'Room designed for hosting exams and assessments with individual desks.');
INSERT INTO shared.room_type (type_name, type_description) VALUES ('Office', NULL);

-- Records of shared.emergency_contact
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('emily.jones@gmail.com', '07400123456', 'Emily', NULL, 'Jones', '12 Apple Street', 'Flat 4', 'London', 'E1 7HP', 'Mother');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('john.smith@yahoo.com', '07411123456', 'John', NULL, 'Smith', '23 Pear Lane', NULL, 'Manchester', 'M2 5NG', 'Father');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('lisa.brown@hotmail.com', '07422123456', 'Lisa', 'Marie', 'Brown', '56 Orange Avenue', 'Apt B', 'Birmingham', 'B12 8PP', 'Sister');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('michael.green@gmail.com', '07433123456', 'Michael', NULL, 'Green', '78 Plum Road', NULL, 'Leeds', 'LS1 4LT', 'Brother');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('sarah.white@yahoo.com', '07444123456', 'Sarah', 'Anne', 'White', '34 Peach Street', NULL, 'Bristol', 'BS1 3AU', 'Aunt');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('david.taylor@hotmail.com', '07455123456', 'David', NULL, 'Taylor', '90 Grape Lane', 'Unit 5', 'Liverpool', 'L1 8JH', 'Uncle');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('jessica.evans@gmail.com', '07466123456', 'Jessica', 'May', 'Evans', '12 Lime Grove', NULL, 'Glasgow', 'G2 8AZ', 'Friend');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('mark.johnson@yahoo.com', '07477123456', 'Mark', NULL, 'Johnson', '33 Berry Street', NULL, 'Edinburgh', 'EH1 2AD', 'Cousin');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('laura.moore@hotmail.com', '07488123456', 'Laura', NULL, 'Moore', '45 Kiwi Road', NULL, 'Cardiff', 'CF10 1AN', 'Colleague');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('steven.harris@gmail.com', '07499123456', 'Steven', 'John', 'Harris', '22 Cherry Lane', NULL, 'Newcastle', 'NE1 3AF', 'Friend');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('anna.clark@yahoo.com', '07500123456', 'Anna', NULL, 'Clark', '11 Maple Drive', NULL, 'Sheffield', 'S1 4DN', 'Niece');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('robert.lewis@hotmail.com', '07511123456', 'Robert', NULL, 'Lewis', '60 Oak Street', NULL, 'Glasgow', 'G3 7HZ', 'Nephew');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('hannah.walker@gmail.com', '07522123456', 'Hannah', NULL, 'Walker', '14 Pine Road', NULL, 'Manchester', 'M14 6QT', 'Cousin');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('thomas.wright@yahoo.com', '07533123456', 'Thomas', NULL, 'Wright', '99 Willow Way', NULL, 'Bristol', 'BS8 2HL', 'Brother');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('megan.james@hotmail.com', '07544123456', 'Megan', NULL, 'James', '88 Cedar Drive', NULL, 'Liverpool', 'L3 5HA', 'Friend');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('charlie.scott@gmail.com', '07555123456', 'Charlie', 'Anne', 'Scott', '77 Maple Lane', NULL, 'Cardiff', 'CF14 2AB', 'Sister');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('isabelle.morris@yahoo.com', '07566123456', 'Isabelle', NULL, 'Morris', '66 Birch Street', NULL, 'Sheffield', 'S2 3FL', 'Aunt');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('matthew.taylor@hotmail.com', '07577123456', 'Matthew', NULL, 'Taylor', '55 Elm Avenue', NULL, 'Newcastle', 'NE6 4BL', 'Uncle');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('rachel.johnson@gmail.com', '07588123456', 'Rachel', NULL, 'Johnson', '44 Hazel Grove', NULL, 'Edinburgh', 'EH2 4DN', 'Friend');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('oliver.hall@yahoo.com', '07599123456', 'Oliver', NULL, 'Hall', '33 Cherry Lane', NULL, 'Birmingham', 'B11 2AF', 'Colleague');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('sophie.anderson@hotmail.com', '07600123456', 'Sophie', NULL, 'Anderson', '22 Peach Street', NULL, 'London', 'E5 9GF', 'Mother');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('benjamin.kim@gmail.com', '07611123456', 'Benjamin', 'Lee', 'Kim', '11 Pine Road', NULL, 'Leeds', 'LS4 2EF', 'Father');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('zoe.baker@yahoo.com', '07622123456', 'Zoe', NULL, 'Baker', '50 Palm Avenue', NULL, 'Bristol', 'BS3 5GH', 'Sister');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('alexander.martinez@hotmail.com', '07633123456', 'Alexander', NULL, 'Martinez', '31 Orchid Lane', NULL, 'Glasgow', 'G41 2QH', 'Brother');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('victoria.lee@gmail.com', '07644123456', 'Victoria', NULL, 'Lee', '29 Magnolia Street', NULL, 'Manchester', 'M16 4FE', 'Aunt');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('luke.davis@yahoo.com', '07655123456', 'Luke', NULL, 'Davis', '89 Willow Way', NULL, 'Cardiff', 'CF15 5HP', 'Uncle');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('natalie.carter@hotmail.com', '07666123456', 'Natalie', NULL, 'Carter', '15 Elm Road', NULL, 'Edinburgh', 'EH3 5JQ', 'Friend');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('chloe.harris@gmail.com', '07677123456', 'Chloe', NULL, 'Harris', '60 Peach Lane', NULL, 'Liverpool', 'L5 1AD', 'Cousin');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('daniel.thomas@yahoo.com', '07688123456', 'Daniel', NULL, 'Thomas', '8 Maple Grove', NULL, 'Birmingham', 'B19 2XT', 'Colleague');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('madison.mitchell@hotmail.com', '07699123456', 'Madison', NULL, 'Mitchell', '7 Cherry Street', NULL, 'Newcastle', 'NE2 3QY', 'Sister');
INSERT INTO shared.emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship) VALUES ('nathan.miller@gmail.com', '07700123456', 'Nathan', NULL, 'Miller', '4 Birch Lane', NULL, 'Sheffield', 'S1 9PL', 'Brother');

-- Records of branch_b01.staff
INSERT INTO branch_b01.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Sophie', NULL, 'Roberts', 'Dr', '123 Maple Street', NULL, 'London', 'SW1A 2AA', 'sophie.roberts@gmail.com', '0113256780', '07912345679');
INSERT INTO branch_b01.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('John', NULL, 'Smith', 'Dr', '789 Elm Street', NULL, 'London', 'SW1A 2AA', 'john.smith@gmail.com', '0201234567', '07891234567');
INSERT INTO branch_b01.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('David', NULL, 'Clark', 'Dr', '789 Pine Avenue', NULL, 'Bristol', 'BS1 1AA', 'david.clark@gmail.com', '0123456789', '07712345678');
INSERT INTO branch_b01.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Michael', NULL, 'Johnson', 'Dr', '123 Cedar Street', NULL, 'London', 'SW1A 2AA', 'michael.johnson@gmail.com', '0131234567', '07723456789');
INSERT INTO branch_b01.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Emily', 'Grace', 'Wilson', 'Dr', '789 Oak Lane', NULL, 'Glasgow', 'G2 1AB', 'emily.wilson@gmail.com', '0113256781', '07912345680');
INSERT INTO branch_b01.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Noah', 'Edward', 'Wilson', 'Dr', '123 Birch Avenue', NULL, 'London', 'SW1A 2AB', 'noah.wilson@gmail.com', '0203456790', '07892345679');
INSERT INTO branch_b01.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Amelia', NULL, 'Thompson', 'Dr', '456 Oak Avenue', NULL, 'Manchester', 'M1 1AA', 'amelia.thompson@gmail.com', '0202345678', '07891234568');

-- Records of branch_b01.staff_role
INSERT INTO branch_b01.staff_role (staff_id, role_id) VALUES ('s000000001', 1);
INSERT INTO branch_b01.staff_role (staff_id, role_id) VALUES ('s000000002', 2);
INSERT INTO branch_b01.staff_role (staff_id, role_id) VALUES ('s000000003', 1);
INSERT INTO branch_b01.staff_role (staff_id, role_id) VALUES ('s000000004', 2);
INSERT INTO branch_b01.staff_role (staff_id, role_id) VALUES ('s000000005', 3);
INSERT INTO branch_b01.staff_role (staff_id, role_id) VALUES ('s000000006', 4);
INSERT INTO branch_b01.staff_role (staff_id, role_id) VALUES ('s000000007', 6);

-- Records of branch_b01.department
INSERT INTO branch_b01.department (dep_id, staff_id) VALUES ('d000001', 's000000001');
INSERT INTO branch_b01.department (dep_id, staff_id) VALUES ('d000003', 's000000003');
INSERT INTO branch_b01.department (dep_id, staff_id) VALUES ('d000007', 's000000005');
INSERT INTO branch_b01.department (dep_id, staff_id) VALUES ('d000010', 's000000006');
INSERT INTO branch_b01.department (dep_id, staff_id) VALUES ('d000009', 's000000007');

-- Records of branch_b01.course
INSERT INTO branch_b01.course (course_id, staff_id) VALUES ('c000001', 's000000001');
INSERT INTO branch_b01.course (course_id, staff_id) VALUES ('c000002', 's000000001');
INSERT INTO branch_b01.course (course_id, staff_id) VALUES ('c000005', 's000000003');
INSERT INTO branch_b01.course (course_id, staff_id) VALUES ('c000006', 's000000003');

-- Records of branch_b01.department_course
INSERT INTO branch_b01.department_course (dep_id, course_id) VALUES ('d000001' , 'c000001');
INSERT INTO branch_b01.department_course (dep_id, course_id) VALUES ('d000001' , 'c000002');
INSERT INTO branch_b01.department_course (dep_id, course_id) VALUES ('d000003' , 'c000005');
INSERT INTO branch_b01.department_course (dep_id, course_id) VALUES ('d000003' , 'c000006');
INSERT INTO branch_b01.department_course (dep_id, course_id) VALUES ('d000003' , 'c000002');

-- Records of branch_b01.module
INSERT INTO branch_b01.module (module_id) VALUES ('m000001');
INSERT INTO branch_b01.module (module_id) VALUES ('m000002');
INSERT INTO branch_b01.module (module_id) VALUES ('m000003');
INSERT INTO branch_b01.module (module_id) VALUES ('m000004');
INSERT INTO branch_b01.module (module_id) VALUES ('m000009');
INSERT INTO branch_b01.module (module_id) VALUES ('m000010');
INSERT INTO branch_b01.module (module_id) VALUES ('m000011');
INSERT INTO branch_b01.module (module_id) VALUES ('m000012');

-- Records of branch_b01.course_module
INSERT INTO branch_b01.course_module (course_id, module_id)  VALUES ('c000001', 'm000001');
INSERT INTO branch_b01.course_module (course_id, module_id)  VALUES ('c000001', 'm000002');
INSERT INTO branch_b01.course_module (course_id, module_id)  VALUES ('c000002', 'm000003');
INSERT INTO branch_b01.course_module (course_id, module_id)  VALUES ('c000002', 'm000004');
INSERT INTO branch_b01.course_module (course_id, module_id)  VALUES ('c000005', 'm000009');
INSERT INTO branch_b01.course_module (course_id, module_id)  VALUES ('c000005', 'm000010');
INSERT INTO branch_b01.course_module (course_id, module_id)  VALUES ('c000006', 'm000011');
INSERT INTO branch_b01.course_module (course_id, module_id)  VALUES ('c000006', 'm000012');

-- Records of branch_b01.student
INSERT INTO branch_b01.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('alex.braun@gmail.com', 'Alex', NULL, 'Braun', 'He/Him', '123 Main Street', 'Mayfair', 'London', 'SW1A 1AA', '0201234570', '07891234572', 0.00);
INSERT INTO branch_b01.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('jane.smith@outlook.com', 'Jane', NULL, 'Smith', 'She/Her', '456 Park Avenue', NULL, 'Manchester', 'M1 1AA', '0161234569', '07987654323', 0.00);
INSERT INTO branch_b01.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('JOHN.doe@yahoo.com', 'John', 'James', 'Doe', 'He/Him', '123 Main Street', 'Kensington', 'London', 'SW1A 1AA', '0201234571', '07891234573', 0.00);
INSERT INTO branch_b01.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('emily.johnson@mail.co.uk', 'Emily', NULL, 'Johnson', 'She/Her', '789 Oak Lane', NULL, 'Birmingham', 'B1 1AA', '0123456789', '07712345678', 0.00);
INSERT INTO branch_b01.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('michael.brown@gmail.com', 'Michael', 'Luke', 'Brown', 'He/Him', '1010 Maple Street', NULL, 'Edinburgh', 'EH1 1AA', '0131234567', '07723456789', 0.00);
INSERT INTO branch_b01.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('emma.williams@gmail.com', 'Emma', NULL, 'Williams', 'She/Her', '789 Cedar Street', NULL, 'London', 'SW1A 2AB', '0203456789', '07892345678', 0.00);

-- Records of branch_b01.student_course
INSERT INTO branch_b01.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000001', 'c000001', NULL, 0.00, TRUE);
INSERT INTO branch_b01.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000002', 'c000001', NULL, 0.00, FALSE);
INSERT INTO branch_b01.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000003', 'c000002', NULL, 0.00, TRUE);
INSERT INTO branch_b01.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000004', 'c000002', NULL, 0.00, FALSE);
INSERT INTO branch_b01.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000005', 'c000005', NULL, 0.00, FALSE);
INSERT INTO branch_b01.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000006', 'c000006', NULL, 0.00, FALSE);

-- Records of branch_b01.tuition
INSERT INTO branch_b01.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (2800.00, 0, 2800.00, 0, '2025-07-01');
INSERT INTO branch_b01.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (2900.00, 0, 2900.00, 0, '2025-08-05');
INSERT INTO branch_b01.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (3000.00, 0, 3000.00, 0, '2025-07-10');
INSERT INTO branch_b01.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (3100.00, 0, 3100.00, 0, '2025-08-15');
INSERT INTO branch_b01.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (3200.00, 0, 3200.00, 0, '2024-07-20');
INSERT INTO branch_b01.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (3300.00, 0, 3300.00, 0, '2024-08-25');

-- Records of branch_b01.student_tuition
INSERT INTO branch_b01.student_tuition (student_id, tuition_id) VALUES ('sn00000001', 1);
INSERT INTO branch_b01.student_tuition (student_id, tuition_id) VALUES ('sn00000002', 2);
INSERT INTO branch_b01.student_tuition (student_id, tuition_id) VALUES ('sn00000003', 3);
INSERT INTO branch_b01.student_tuition (student_id, tuition_id) VALUES ('sn00000004', 4);
INSERT INTO branch_b01.student_tuition (student_id, tuition_id) VALUES ('sn00000005', 5);
INSERT INTO branch_b01.student_tuition (student_id, tuition_id) VALUES ('sn00000006', 6);

-- Records of branch_b01.tuition_payment
INSERT INTO branch_b01.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (1, 300.00, '2025-03-15', 'Bank Transfer');
INSERT INTO branch_b01.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (2, 200.00, '2025-03-20', 'Bank Transfer');
INSERT INTO branch_b01.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (3, 400.00, '2025-04-10', 'Direct Debit');
INSERT INTO branch_b01.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (4, 600.00, '2025-04-20', 'Direct Debit');
INSERT INTO branch_b01.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (5, 500.00, '2025-05-10', 'Direct Debit');
INSERT INTO branch_b01.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (6, 200.00, '2025-05-20', 'Direct Debit');

-- Records of branch_b01.staff_department
INSERT INTO branch_b01.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000001', 'd000001', '2025-02-01');
INSERT INTO branch_b01.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000002', 'd000001', '2025-02-02');
INSERT INTO branch_b01.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000003', 'd000003', '2025-03-02');
INSERT INTO branch_b01.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000004', 'd000003', '2025-02-06');
INSERT INTO branch_b01.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000005', 'd000007', '2025-04-02');
INSERT INTO branch_b01.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000006', 'd000010', '2025-02-09');
INSERT INTO branch_b01.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000007', 'd000009', '2025-05-02');

-- Records of branch_b01.building
INSERT INTO branch_b01.building (building_name, building_alt_name, building_type, building_addr1, building_addr2, building_city, building_postcode, building_country) VALUES ('Turing Hall', 'TH', 'Educational', '12 Science Way', 'South Bank', 'London', 'SW1A 1AA', 'United Kingdom');
INSERT INTO branch_b01.building (building_name, building_alt_name, building_type, building_addr1, building_addr2, building_city, building_postcode, building_country) VALUES ('Ada Lovelace Building', 'ALB', 'Administrative', '98 King Street', 'Mayfair', 'London', 'SW1A 1AB', 'United Kingdom');

-- Records of branch_b01.room
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, 'Lecture Theatre 1', 'LT1', 1, 100, 1);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '1.02', 'TH1.01', 4, 40, 1);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '1.04', 'TH1.02', 2, 25, 1);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '2.01', 'TH2.01', 13, 1, 2);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '2.02', 'TH2.02', 13, 1, 2);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '2.03', 'TH2.03', 13, 1, 2);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '2.04', 'TH2.04', 13, 1, 2);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '1.05', 'ALB1.01', 13, 1, 1);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '1.05', 'ALB1.02', 13, 1, 1);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '1.05', 'ALB1.03', 13, 1, 1);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '1.05', 'ALB1.04', 13, 1, 1);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '2.01', 'ALB2.01', 13, 1, 2);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '2.02', 'ALB2.02', 13, 1, 2);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '2.03', 'ALB2.03', 13, 1, 2);
INSERT INTO branch_b01.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '2.04', 'ALB2.04', 13, 1, 2);

-- Records of branch_b01.room_facility
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (1, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (1, 2, 2);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (2, 1, 25);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (2, 2, 2);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (2, 12, 2);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (3, 1, 10);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (3, 2, 2);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (4, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (5, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (6, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (7, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (8, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (9, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (10, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (11, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (12, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (13, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (14, 1, 1);
INSERT INTO branch_b01.room_facility (room_id, facility_id, quantity) VALUES (15, 1, 1);

-- Records of branch_b01.session
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000001', 'Practical', '10:00', '11:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000001', 'Practical', '10:00', '11:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000001', 'Practical', '10:00', '11:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000001', 'Practical', '10:00', '11:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000001', 'Practical', '10:00', '11:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000001', 'Practical', '10:00', '11:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000001', 'Practical', '10:00', '11:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000001', 'Practical', '10:00', '11:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000001', 'Practical', '10:00', '11:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000001', 'Practical', '10:00', '11:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000001', 'Practical', '10:00', '11:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000001', 'Lecture', '9:00', '10:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000001', 'Practical', '10:00', '11:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000002', 'Practical', '11:00', '12:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000002', 'Practical', '11:00', '12:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000002', 'Practical', '11:00', '12:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000002', 'Practical', '11:00', '12:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000002', 'Practical', '11:00', '12:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000002', 'Practical', '11:00', '12:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000002', 'Practical', '11:00', '12:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000002', 'Practical', '11:00', '12:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000002', 'Practical', '11:00', '12:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000002', 'Practical', '11:00', '12:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000002', 'Practical', '11:00', '12:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000002', 'Lecture', '10:00', '11:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000002', 'Practical', '11:00', '12:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000003', 'Practical', '12:00', '13:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000003', 'Practical', '12:00', '13:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000003', 'Practical', '12:00', '13:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000003', 'Practical', '12:00', '13:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000003', 'Practical', '12:00', '13:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000003', 'Practical', '12:00', '13:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000003', 'Practical', '12:00', '13:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000003', 'Practical', '12:00', '13:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000003', 'Practical', '12:00', '13:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000003', 'Practical', '12:00', '13:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000003', 'Practical', '12:00', '13:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000003', 'Lecture', '11:00', '12:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000003', 'Practical', '12:00', '13:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000004', 'Practical', '13:00', '14:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000004', 'Practical', '13:00', '14:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000004', 'Practical', '13:00', '14:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000004', 'Practical', '13:00', '14:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000004', 'Practical', '13:00', '14:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000004', 'Practical', '13:00', '14:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000004', 'Practical', '13:00', '14:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000004', 'Lecture', '12:00', '13:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000004', 'Practical', '13:00', '14:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000009', 'Practical', '14:00', '15:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000009', 'Practical', '14:00', '15:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000009', 'Practical', '14:00', '15:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000009', 'Practical', '14:00', '15:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000009', 'Practical', '14:00', '15:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000009', 'Practical', '14:00', '15:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000009', 'Practical', '14:00', '15:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000009', 'Practical', '14:00', '15:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000009', 'Practical', '14:00', '15:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000009', 'Practical', '14:00', '15:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000009', 'Practical', '14:00', '15:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000009', 'Lecture', '13:00', '14:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000009', 'Practical', '14:00', '15:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000010', 'Practical', '15:00', '16:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000010', 'Practical', '15:00', '16:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000010', 'Practical', '15:00', '16:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000010', 'Practical', '15:00', '16:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000010', 'Practical', '15:00', '16:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000010', 'Practical', '15:00', '16:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000010', 'Practical', '15:00', '16:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000010', 'Practical', '15:00', '16:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000010', 'Practical', '15:00', '16:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000010', 'Practical', '15:00', '16:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000010', 'Practical', '15:00', '16:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000010', 'Lecture', '14:00', '15:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000010', 'Practical', '15:00', '16:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000011', 'Practical', '16:00', '17:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000011', 'Practical', '16:00', '17:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000011', 'Practical', '16:00', '17:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000011', 'Practical', '16:00', '17:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000011', 'Practical', '16:00', '17:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000011', 'Practical', '16:00', '17:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000011', 'Practical', '16:00', '17:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000011', 'Practical', '16:00', '17:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000011', 'Practical', '16:00', '17:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000011', 'Practical', '16:00', '17:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000011', 'Practical', '16:00', '17:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000011', 'Lecture', '15:00', '16:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000011', 'Practical', '16:00', '17:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000012', 'Practical', '17:00', '18:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000012', 'Practical', '17:00', '18:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000012', 'Practical', '17:00', '18:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000012', 'Practical', '17:00', '18:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000012', 'Practical', '17:00', '18:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000012', 'Practical', '17:00', '18:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000012', 'Practical', '17:00', '18:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000012', 'Practical', '17:00', '18:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000012', 'Practical', '17:00', '18:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000012', 'Practical', '17:00', '18:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000012', 'Practical', '17:00', '18:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000012', 'Lecture', '16:00', '17:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b01.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000012', 'Practical', '17:00', '18:00', '2025-01-21', '', TRUE, '');

-- Records of branch_b01.staff_session
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000001');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000001');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000002');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000002');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000003');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000003');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000004');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000004');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000005');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000005');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000006');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000006');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000007');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000007');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000008');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000008');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000009');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000009');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000010');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000010');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000011');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000011');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000012');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000012');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000013');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000013');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000014');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000014');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000015');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000015');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000016');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000016');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000017');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000017');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000018');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000018');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000019');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000019');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000020');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000020');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000021');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000021');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000022');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000022');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000023');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000023');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000024');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000024');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000025');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000025');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000026');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000026');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000027');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000027');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000028');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000028');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000029');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000029');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000030');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000030');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000031');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000031');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000032');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000032');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000033');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000033');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000034');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000034');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000035');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000035');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000036');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000036');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000037');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000037');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000038');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000038');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000039');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000039');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000040');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000040');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000041');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000041');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000042');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000042');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000043');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000043');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000044');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000044');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000045');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000045');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000046');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000046');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000047');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000047');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000048');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000048');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000049');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000050');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000051');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000051');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000052');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000052');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000053');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000053');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000054');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000054');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000055');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000055');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000056');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000056');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000057');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000057');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000058');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000058');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000059');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000059');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000060');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000060');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000061');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000061');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000062');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000062');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000063');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000063');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000064');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000064');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000065');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000065');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000066');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000066');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000067');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000067');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000068');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000068');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000069');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000069');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000070');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000070');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000071');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000071');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000072');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000072');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000073');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000073');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000074');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000074');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000075');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000075');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000076');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000076');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000077');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000077');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000078');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000078');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000079');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000079');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000080');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000080');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000081');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000081');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000082');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000082');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000083');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000083');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000084');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000084');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000085');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000085');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000086');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000086');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000087');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000087');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000088');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000088');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000089');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000089');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000090');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000090');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000091');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000091');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000092');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000092');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000093');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000093');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000094');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000094');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000095');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000095');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000001', 'sesh000096');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000096');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000097');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000097');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000098');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000098');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000099');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000099');

-- Records of branch_b01.staff_session
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000101');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000101');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000102');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000102');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000103');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000103');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000104');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000104');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000105');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000105');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000106');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000106');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000107');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000107');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000108');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000108');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000109');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000109');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000110');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000110');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000111');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000111');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000112');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000112');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000113');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000113');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000114');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000114');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000115');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000115');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000116');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000116');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000117');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000117');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000118');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000118');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000119');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000119');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000120');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000120');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000121');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000121');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000122');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000122');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000123');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000123');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000124');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000124');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000125');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000125');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000126');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000126');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000127');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000127');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000128');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000128');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000129');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000129');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000130');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000130');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000131');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000131');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000132');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000132');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000133');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000133');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000134');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000134');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000135');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000135');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000136');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000136');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000137');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000137');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000138');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000138');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000139');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000139');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000140');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000140');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000141');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000141');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000142');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000142');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000143');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000143');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000144');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000144');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000145');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000145');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000146');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000146');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000147');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000147');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000148');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000148');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000149');

-- Records of branch_b01.staff_session
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000150');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000151');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000151');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000152');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000152');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000153');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000153');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000154');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000154');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000155');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000155');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000156');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000156');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000157');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000157');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000158');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000158');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000159');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000159');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000160');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000160');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000161');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000161');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000162');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000162');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000163');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000163');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000164');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000164');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000165');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000165');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000166');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000166');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000167');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000167');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000168');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000168');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000169');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000169');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000170');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000170');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000171');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000171');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000172');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000172');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000173');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000173');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000174');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000174');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000175');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000175');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000176');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000176');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000177');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000177');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000178');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000178');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000179');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000179');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000180');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000180');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000181');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000181');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000182');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000182');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000183');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000183');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000184');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000184');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000185');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000185');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000186');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000186');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000187');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000187');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000188');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000188');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000189');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000189');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000190');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000190');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000191');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000191');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000002', 'sesh000192');
INSERT INTO branch_b01.staff_session (staff_id, session_id) VALUES ('s000000003', 'sesh000192');

-- Records of branch_b01.staff_contact
INSERT INTO branch_b01.staff_contact (contact_id, staff_id) VALUES (1, 's000000001');
INSERT INTO branch_b01.staff_contact (contact_id, staff_id) VALUES (2, 's000000002');
INSERT INTO branch_b01.staff_contact (contact_id, staff_id) VALUES (3, 's000000003');
INSERT INTO branch_b01.staff_contact (contact_id, staff_id) VALUES (4, 's000000004');
INSERT INTO branch_b01.staff_contact (contact_id, staff_id) VALUES (5, 's000000005');
INSERT INTO branch_b01.staff_contact (contact_id, staff_id) VALUES (6, 's000000006');
INSERT INTO branch_b01.staff_contact (contact_id, staff_id) VALUES (7, 's000000007');

-- Records of branch_b01.student_contact
INSERT INTO branch_b01.student_contact (contact_id, student_id) VALUES (10, 'sn00000001');
INSERT INTO branch_b01.student_contact (contact_id, student_id) VALUES (1, 'sn00000002');
INSERT INTO branch_b01.student_contact (contact_id, student_id) VALUES (12, 'sn00000003');
INSERT INTO branch_b01.student_contact (contact_id, student_id) VALUES (8, 'sn00000004');
INSERT INTO branch_b01.student_contact (contact_id, student_id) VALUES (3, 'sn00000005');
INSERT INTO branch_b01.student_contact (contact_id, student_id) VALUES (11, 'sn00000006');

-- Records of branch_b01.staff_office
INSERT INTO branch_b01.staff_office (room_id, staff_id) VALUES (4,'s000000001');
INSERT INTO branch_b01.staff_office (room_id, staff_id) VALUES (5,'s000000002');
INSERT INTO branch_b01.staff_office (room_id, staff_id) VALUES (6,'s000000003');
INSERT INTO branch_b01.staff_office (room_id, staff_id) VALUES (7,'s000000004');
INSERT INTO branch_b01.staff_office (room_id, staff_id) VALUES (8,'s000000005');
INSERT INTO branch_b01.staff_office (room_id, staff_id) VALUES (9,'s000000006');
INSERT INTO branch_b01.staff_office (room_id, staff_id) VALUES (10,'s000000007');

/* UPDATE SEED DATA */
-- Assign random grades to all student assessments
UPDATE branch_b01.student_assessment
SET grade = ROUND(CAST((random() * 100) AS numeric), 2);

-- Update attendance records (randomly) for all sessions that have passed
UPDATE branch_b01.student_session AS ss
SET attendance_record = (
  CASE 
    WHEN RANDOM() > 0.5 THEN TRUE
    ELSE FALSE
  END
)
WHERE EXISTS (
  SELECT 1
  FROM branch_b01.session AS s
  WHERE s.session_id = ss.session_id
    AND s.session_date < CURRENT_DATE
);

-- Records of branch_b02.staff
INSERT INTO branch_b02.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Ethan', 'William', 'White', 'Dr', '789 Pine Avenue', NULL, 'Glasgow', 'G1 1AA', 'ethan.white@gmail.com', '0162345679', '07987654322');
INSERT INTO branch_b02.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('William', 'Daniel', 'Thomas', 'Dr', '789 Elm Street', NULL, 'Glasgow', 'G1 1AA', 'william.thomas@gmail.com', '0161234568', '07987554322');
INSERT INTO branch_b02.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Isabella', NULL, 'Harris', 'Dr', '456 Maple Street', NULL, 'Manchester', 'M1 2AB', 'isabella.harris@gmail.com', '0163456791', '07998765433');
INSERT INTO branch_b02.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('James', 'Alexander', 'Brown', 'Dr', '789 Oak Lane', NULL, 'Glasgow', 'G2 1AB', 'james.brown@gmail.com', '0112345670', '07871234568');
INSERT INTO branch_b02.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Charlotte', NULL, 'Wilson', 'Dr', '101 Elm Street', NULL, 'Bristol', 'BS2 1AB', 'charlotte.wilson@gmail.com', '0142345679', '07876543211');
INSERT INTO branch_b02.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Laura', 'James', 'Taylor', 'Ms', '456 Elm Street', NULL, 'Glasgow', 'G1 1AA', 'laura.taylor@gmail.com', '0201234512', '07891232567');
INSERT INTO branch_b02.staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile) VALUES ('Jane', NULL, 'Doe', 'Mrs', '987 Oak Avenue', NULL, 'Manchester', 'M1 2AA', 'jAne.doe@gmail.com', '0161234567', '07987654321');

-- Records of branch_b02.staff_role
INSERT INTO branch_b02.staff_role (staff_id, role_id) VALUES ('s000000008', 1);
INSERT INTO branch_b02.staff_role (staff_id, role_id) VALUES ('s000000009', 2);
INSERT INTO branch_b02.staff_role (staff_id, role_id) VALUES ('s000000010', 1);
INSERT INTO branch_b02.staff_role (staff_id, role_id) VALUES ('s000000011', 2);
INSERT INTO branch_b02.staff_role (staff_id, role_id) VALUES ('s000000012', 3);
INSERT INTO branch_b02.staff_role (staff_id, role_id) VALUES ('s000000013', 4);
INSERT INTO branch_b02.staff_role (staff_id, role_id) VALUES ('s000000014', 6);

-- Records of branch_b02.department
INSERT INTO branch_b02.department (dep_id, staff_id) VALUES ('d000004', 's000000008');
INSERT INTO branch_b02.department (dep_id, staff_id) VALUES ('d000005', 's000000010');
INSERT INTO branch_b02.department (dep_id, staff_id) VALUES ('d000007', 's000000012');
INSERT INTO branch_b02.department (dep_id, staff_id) VALUES ('d000010', 's000000013');
INSERT INTO branch_b02.department (dep_id, staff_id) VALUES ('d000009', 's000000014');

-- Records of branch_b02.course
INSERT INTO branch_b02.course (course_id, staff_id) VALUES ('c000007', 's000000008');
INSERT INTO branch_b02.course (course_id, staff_id) VALUES ('c000008', 's000000008');
INSERT INTO branch_b02.course (course_id, staff_id) VALUES ('c000009', 's000000010');
INSERT INTO branch_b02.course (course_id, staff_id) VALUES ('c000010', 's000000010');

-- Records of branch_b02.department_course
INSERT INTO branch_b02.department_course (dep_id, course_id) VALUES ('d000004' , 'c000007');
INSERT INTO branch_b02.department_course (dep_id, course_id) VALUES ('d000004' , 'c000008');
INSERT INTO branch_b02.department_course (dep_id, course_id) VALUES ('d000005' , 'c000009');
INSERT INTO branch_b02.department_course (dep_id, course_id) VALUES ('d000005' , 'c000010');
INSERT INTO branch_b02.department_course (dep_id, course_id) VALUES ('d000005' , 'c000008');

-- Records of branch_b02.module
INSERT INTO branch_b02.module (module_id) VALUES ('m000013');
INSERT INTO branch_b02.module (module_id) VALUES ('m000014');
INSERT INTO branch_b02.module (module_id) VALUES ('m000015');
INSERT INTO branch_b02.module (module_id) VALUES ('m000016');
INSERT INTO branch_b02.module (module_id) VALUES ('m000017');
INSERT INTO branch_b02.module (module_id) VALUES ('m000018');
INSERT INTO branch_b02.module (module_id) VALUES ('m000019');
INSERT INTO branch_b02.module (module_id) VALUES ('m000020');

-- Records of branch_b02.course_module
INSERT INTO branch_b02.course_module (course_id, module_id)  VALUES ('c000007', 'm000013');
INSERT INTO branch_b02.course_module (course_id, module_id)  VALUES ('c000007', 'm000014');
INSERT INTO branch_b02.course_module (course_id, module_id)  VALUES ('c000008', 'm000015');
INSERT INTO branch_b02.course_module (course_id, module_id)  VALUES ('c000008', 'm000016');
INSERT INTO branch_b02.course_module (course_id, module_id)  VALUES ('c000009', 'm000017');
INSERT INTO branch_b02.course_module (course_id, module_id)  VALUES ('c000009', 'm000018');
INSERT INTO branch_b02.course_module (course_id, module_id)  VALUES ('c000010', 'm000019');
INSERT INTO branch_b02.course_module (course_id, module_id)  VALUES ('c000010', 'm000020');

-- Records of branch_b02.student
INSERT INTO branch_b02.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('alexander.brown@gmail.com', 'Alexander', 'James', 'Brown', 'He/Him', '456 Birch Avenue', NULL, 'Manchester', 'M1 2AB', '0163456789', '07998765432', 0.00);
INSERT INTO branch_b02.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('olivia.taylor@gmail.com', 'Olivia', NULL, 'Taylor', 'She/Her', '101 Elm Street', NULL, 'Glasgow', 'G2 1AB', '0142345671', '07871234571', 0.00);
INSERT INTO branch_b02.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('will.thomas@gmail.com', 'William', 'John', 'Thomas', 'He/Him', '789 Oak Lane', NULL, 'Bristol', 'BS2 1AB', '0113456781', '07912335681', 0.00);
INSERT INTO branch_b02.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('will.james@gmail.com', 'Will', NULL, 'James', 'He/Him', '125 Cedar Lane', NULL, 'London', 'SW1A 4AB', '0113456780', '07912345581', 0.00);
INSERT INTO branch_b02.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('amanda.thomas@gmail.com', 'Amanda', NULL, 'Thomas', 'She/Her', '789 Oak Lane', NULL, 'Bristol', 'BS2 1AB', '0113456781', '07912345681', 0.00);
INSERT INTO branch_b02.student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_attendance) VALUES ('amanda.james@gmail.com', 'Amanda', NULL, 'James', 'She/Her', '125 Cedar Lane', NULL, 'Bristol', 'BS2 1AB', '0113456281', '07952345681', 0.00);

-- Records of branch_b02.student_course
INSERT INTO branch_b02.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000007', 'c000007', NULL, 0.00, TRUE);
INSERT INTO branch_b02.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000008', 'c000007', NULL, 0.00, FALSE);
INSERT INTO branch_b02.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000009', 'c000008', NULL, 0.00, TRUE);
INSERT INTO branch_b02.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000010', 'c000008', NULL, 0.00, FALSE);
INSERT INTO branch_b02.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000011', 'c000009', NULL, 0.00, FALSE);
INSERT INTO branch_b02.student_course (student_id, course_id, feedback, culmative_average, course_rep) VALUES ('sn00000012', 'c000010', NULL, 0.00, FALSE);

-- Records of branch_b02.tuition
INSERT INTO branch_b02.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (2800.00, 0, 2800.00, 0, '2025-07-01');
INSERT INTO branch_b02.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (2900.00, 0, 2900.00, 0, '2025-08-05');
INSERT INTO branch_b02.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (3000.00, 0, 3000.00, 0, '2025-07-10');
INSERT INTO branch_b02.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (3100.00, 0, 3100.00, 0, '2024-08-15');
INSERT INTO branch_b02.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (3200.00, 0, 3200.00, 0, '2024-07-20');
INSERT INTO branch_b02.tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline) VALUES (3300.00, 0, 3300.00, 0, '2024-08-25');

-- Records of branch_b02.student_tuition
INSERT INTO branch_b02.student_tuition (student_id, tuition_id) VALUES ('sn00000007', 1);
INSERT INTO branch_b02.student_tuition (student_id, tuition_id) VALUES ('sn00000008', 2);
INSERT INTO branch_b02.student_tuition (student_id, tuition_id) VALUES ('sn00000009', 3);
INSERT INTO branch_b02.student_tuition (student_id, tuition_id) VALUES ('sn00000010', 4);
INSERT INTO branch_b02.student_tuition (student_id, tuition_id) VALUES ('sn00000011', 5);
INSERT INTO branch_b02.student_tuition (student_id, tuition_id) VALUES ('sn00000012', 6);

-- Records of branch_b02.tuition_payment
INSERT INTO branch_b02.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (1, 2800.00, '2025-03-15', 'Bank Transfer');
INSERT INTO branch_b02.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (2, 1200.00, '2025-03-20', 'Bank Transfer');
INSERT INTO branch_b02.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (3, 400.00, '2025-04-10', 'Direct Debit');
INSERT INTO branch_b02.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (4, 2000.00, '2025-04-20', 'Direct Debit');
INSERT INTO branch_b02.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (5, 600.00, '2025-05-10', 'Direct Debit');
INSERT INTO branch_b02.tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method) VALUES (6, 900.00, '2025-05-20', 'Direct Debit');

-- Records of branch_b02.staff_department
INSERT INTO branch_b02.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000008', 'd000004', '2025-02-01');
INSERT INTO branch_b02.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000009', 'd000004', '2025-02-02');
INSERT INTO branch_b02.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000010', 'd000005', '2025-03-02');
INSERT INTO branch_b02.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000011', 'd000005', '2025-02-06');
INSERT INTO branch_b02.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000012', 'd000007', '2025-04-02');
INSERT INTO branch_b02.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000013', 'd000010', '2025-02-09');
INSERT INTO branch_b02.staff_department (staff_id, dep_id, date_assinged) VALUES ('s000000014', 'd000009', '2025-05-02');

-- Records of branch_b02.building
INSERT INTO branch_b02.building (building_name, building_alt_name, building_type, building_addr1, building_addr2, building_city, building_postcode, building_country) VALUES ('Nancy Rothwell', 'NR', 'Educational', '4 Oxford Street', NULL, 'Manchester', 'M1 1AA', 'United Kingdom');
INSERT INTO branch_b02.building (building_name, building_alt_name, building_type, building_addr1, building_addr2, building_city, building_postcode, building_country) VALUES ('Crawford House', 'CH', 'Administrative', '1 Charles Street', NULL, 'Manchester', 'M1 1AB', 'United Kingdom');

-- Records of branch_b02.room
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, 'Lecture Theatre 1', 'LT1', 1, 100, 1);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '1.02', 'NR1.01', 4, 40, 1);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '1.04', 'NR1.02', 2, 25, 1);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '2.01', 'NR2.01', 13, 1, 2);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '2.02', 'NR2.02', 13, 1, 2);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '2.03', 'NR2.03', 13, 1, 2);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (1, '2.04', 'NR2.04', 13, 1, 2);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '1.05', 'CH1.01', 13, 1, 1);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '1.05', 'CH1.02', 13, 1, 1);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '1.05', 'CH1.03', 13, 1, 1);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '1.05', 'CH1.04', 13, 1, 1);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '2.01', 'CH2.01', 13, 1, 2);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '2.02', 'CH2.02', 13, 1, 2);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '2.03', 'CH2.03', 13, 1, 2);
INSERT INTO branch_b02.room (building_id, room_name, room_alt_name, room_type_id, room_capacity, room_floor) VALUES (2, '2.04', 'CH2.04', 13, 1, 2);

-- Records of branch_b02.room_facility
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (1, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (1, 2, 2);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (2, 1, 25);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (2, 2, 2);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (2, 12, 2);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (3, 1, 10);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (3, 2, 2);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (4, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (5, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (6, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (7, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (8, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (9, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (10, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (11, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (12, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (13, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (14, 1, 1);
INSERT INTO branch_b02.room_facility (room_id, facility_id, quantity) VALUES (15, 1, 1);

-- Records of branch_b02.session
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000013', 'Practical', '10:00', '11:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000013', 'Practical', '10:00', '11:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000013', 'Practical', '10:00', '11:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000013', 'Practical', '10:00', '11:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000013', 'Practical', '10:00', '11:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000013', 'Practical', '10:00', '11:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000013', 'Practical', '10:00', '11:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000013', 'Practical', '10:00', '11:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000013', 'Practical', '10:00', '11:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000013', 'Practical', '10:00', '11:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000013', 'Practical', '10:00', '11:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000013', 'Lecture', '9:00', '10:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000013', 'Practical', '10:00', '11:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000014', 'Practical', '11:00', '12:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000014', 'Practical', '11:00', '12:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000014', 'Practical', '11:00', '12:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000014', 'Practical', '11:00', '12:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000014', 'Practical', '11:00', '12:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000014', 'Practical', '11:00', '12:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000014', 'Practical', '11:00', '12:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000014', 'Practical', '11:00', '12:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000014', 'Practical', '11:00', '12:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000014', 'Practical', '11:00', '12:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000014', 'Practical', '11:00', '12:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000014', 'Lecture', '10:00', '11:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000014', 'Practical', '11:00', '12:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000015', 'Practical', '12:00', '13:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000015', 'Practical', '12:00', '13:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000015', 'Practical', '12:00', '13:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000015', 'Practical', '12:00', '13:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000015', 'Practical', '12:00', '13:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000015', 'Practical', '12:00', '13:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000015', 'Practical', '12:00', '13:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000015', 'Practical', '12:00', '13:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000015', 'Practical', '12:00', '13:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000015', 'Practical', '12:00', '13:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000015', 'Practical', '12:00', '13:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000015', 'Lecture', '11:00', '12:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000015', 'Practical', '12:00', '13:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000016', 'Practical', '13:00', '14:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000016', 'Practical', '13:00', '14:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000016', 'Practical', '13:00', '14:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000016', 'Practical', '13:00', '14:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000016', 'Practical', '13:00', '14:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000016', 'Practical', '13:00', '14:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000016', 'Practical', '13:00', '14:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000016', 'Practical', '13:00', '14:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000016', 'Practical', '13:00', '14:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000016', 'Practical', '13:00', '14:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000016', 'Practical', '13:00', '14:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000016', 'Lecture', '12:00', '13:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000016', 'Practical', '13:00', '14:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000017', 'Practical', '14:00', '15:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000017', 'Practical', '14:00', '15:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000017', 'Practical', '14:00', '15:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000017', 'Practical', '14:00', '15:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000017', 'Practical', '14:00', '15:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000017', 'Practical', '14:00', '15:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000017', 'Practical', '14:00', '15:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000017', 'Practical', '14:00', '15:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000017', 'Practical', '14:00', '15:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000017', 'Practical', '14:00', '15:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000017', 'Practical', '14:00', '15:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000017', 'Lecture', '13:00', '14:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000017', 'Practical', '14:00', '15:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000018', 'Practical', '15:00', '16:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000018', 'Practical', '15:00', '16:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000018', 'Practical', '15:00', '16:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000018', 'Practical', '15:00', '16:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000018', 'Practical', '15:00', '16:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000018', 'Practical', '15:00', '16:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000018', 'Practical', '15:00', '16:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000018', 'Practical', '15:00', '16:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000018', 'Practical', '15:00', '16:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000018', 'Practical', '15:00', '16:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000018', 'Practical', '15:00', '16:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000018', 'Lecture', '14:00', '15:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000018', 'Practical', '15:00', '16:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000019', 'Practical', '16:00', '17:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000019', 'Practical', '16:00', '17:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000019', 'Practical', '16:00', '17:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000019', 'Practical', '16:00', '17:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000019', 'Practical', '16:00', '17:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000019', 'Practical', '16:00', '17:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000019', 'Practical', '16:00', '17:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000019', 'Practical', '16:00', '17:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000019', 'Practical', '16:00', '17:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000019', 'Practical', '16:00', '17:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000019', 'Practical', '16:00', '17:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000019', 'Lecture', '15:00', '16:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000019', 'Practical', '16:00', '17:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000020', 'Practical', '17:00', '18:00', '2024-11-05', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000020', 'Practical', '17:00', '18:00', '2024-11-12', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000020', 'Practical', '17:00', '18:00', '2024-11-19', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000020', 'Practical', '17:00', '18:00', '2024-11-26', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000020', 'Practical', '17:00', '18:00', '2024-12-03', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000020', 'Practical', '17:00', '18:00', '2024-12-10', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000020', 'Practical', '17:00', '18:00', '2024-12-17', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000020', 'Practical', '17:00', '18:00', '2024-12-24', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000020', 'Practical', '17:00', '18:00', '2024-12-31', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000020', 'Practical', '17:00', '18:00', '2025-01-07', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (2, 'm000020', 'Practical', '17:00', '18:00', '2025-01-14', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (1, 'm000020', 'Lecture', '16:00', '17:00', '2025-01-21', '', TRUE, '');
INSERT INTO branch_b02.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description) VALUES (3, 'm000020', 'Practical', '17:00', '18:00', '2025-01-21', '', TRUE, '');

-- Records of branch_b02.staff_session
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000194');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000194');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000195');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000195');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000196');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000196');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000197');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000197');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000198');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000198');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000199');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000199');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000200');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000200');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000201');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000201');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000202');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000202');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000203');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000203');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000204');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000204');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000205');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000205');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000206');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000206');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000207');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000207');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000208');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000208');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000209');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000209');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000210');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000210');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000211');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000211');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000212');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000212');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000213');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000213');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000214');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000214');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000215');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000215');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000216');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000216');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000217');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000217');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000218');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000218');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000219');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000219');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000220');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000220');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000221');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000221');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000222');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000222');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000223');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000223');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000224');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000224');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000225');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000225');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000226');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000226');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000227');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000227');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000228');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000228');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000229');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000229');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000230');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000230');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000231');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000231');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000232');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000232');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000233');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000233');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000234');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000234');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000235');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000235');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000236');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000236');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000237');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000237');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000238');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000238');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000239');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000239');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000240');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000240');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000241');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000241');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000242');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000242');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000243');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000243');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000244');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000244');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000245');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000245');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000246');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000246');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000247');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000247');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000248');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000248');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000249');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000249');

-- Records of branch_b02.staff_session
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000251');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000251');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000252');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000252');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000253');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000253');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000254');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000254');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000255');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000255');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000256');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000256');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000257');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000257');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000258');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000258');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000259');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000259');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000260');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000260');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000261');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000261');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000262');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000262');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000263');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000263');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000264');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000264');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000265');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000265');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000266');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000266');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000267');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000267');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000268');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000268');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000269');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000269');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000270');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000270');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000271');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000271');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000272');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000272');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000273');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000273');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000274');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000274');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000275');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000275');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000276');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000276');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000277');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000277');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000278');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000278');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000279');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000279');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000280');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000280');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000281');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000281');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000282');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000282');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000283');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000283');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000284');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000284');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000285');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000285');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000286');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000286');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000287');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000287');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000288');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000288');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000008', 'sesh000289');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000289');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000290');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000290');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000291');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000291');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000292');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000292');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000293');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000293');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000294');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000294');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000295');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000295');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000296');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000296');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000297');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000297');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000298');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000298');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000299');

-- Records of branch_b02.staff_session
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000300');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000301');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000301');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000302');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000302');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000303');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000303');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000304');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000304');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000305');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000305');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000306');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000306');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000307');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000307');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000308');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000308');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000309');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000309');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000310');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000310');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000311');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000311');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000312');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000312');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000313');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000313');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000314');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000314');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000315');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000315');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000316');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000316');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000317');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000317');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000318');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000318');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000319');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000319');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000320');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000320');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000321');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000321');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000322');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000322');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000323');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000323');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000324');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000324');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000325');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000325');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000326');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000326');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000327');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000327');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000328');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000328');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000329');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000329');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000330');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000330');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000331');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000331');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000332');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000332');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000333');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000333');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000334');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000334');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000335');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000335');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000336');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000336');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000337');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000337');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000338');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000338');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000339');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000339');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000340');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000340');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000341');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000341');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000342');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000342');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000343');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000343');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000344');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000344');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000345');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000345');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000346');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000346');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000347');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000347');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000348');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000348');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000349');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000349');

-- Records of branch_b02.staff_session
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000351');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000351');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000352');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000352');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000353');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000353');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000354');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000354');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000355');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000355');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000356');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000356');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000357');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000357');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000358');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000358');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000359');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000359');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000360');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000360');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000361');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000361');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000362');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000362');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000363');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000363');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000364');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000364');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000365');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000365');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000366');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000366');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000367');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000367');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000368');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000368');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000369');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000369');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000370');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000370');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000371');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000371');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000372');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000372');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000373');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000373');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000374');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000374');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000375');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000375');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000376');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000376');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000377');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000377');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000378');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000378');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000379');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000379');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000380');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000380');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000381');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000381');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000382');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000382');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000383');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000383');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000009', 'sesh000384');
INSERT INTO branch_b02.staff_session (staff_id, session_id) VALUES ('s000000010', 'sesh000384');

-- Records of branch_b02.staff_contact
INSERT INTO branch_b02.staff_contact (contact_id, staff_id) VALUES (1, 's000000008');
INSERT INTO branch_b02.staff_contact (contact_id, staff_id) VALUES (2, 's000000009');
INSERT INTO branch_b02.staff_contact (contact_id, staff_id) VALUES (3, 's000000010');
INSERT INTO branch_b02.staff_contact (contact_id, staff_id) VALUES (4, 's000000011');
INSERT INTO branch_b02.staff_contact (contact_id, staff_id) VALUES (5, 's000000012');
INSERT INTO branch_b02.staff_contact (contact_id, staff_id) VALUES (6, 's000000013');
INSERT INTO branch_b02.staff_contact (contact_id, staff_id) VALUES (7, 's000000014');

-- Records of branch_b02.student_contact
INSERT INTO branch_b02.student_contact (contact_id, student_id) VALUES (10, 'sn00000007');
INSERT INTO branch_b02.student_contact (contact_id, student_id) VALUES (1, 'sn00000008');
INSERT INTO branch_b02.student_contact (contact_id, student_id) VALUES (12, 'sn00000009');
INSERT INTO branch_b02.student_contact (contact_id, student_id) VALUES (8, 'sn00000010');
INSERT INTO branch_b02.student_contact (contact_id, student_id) VALUES (3, 'sn00000011');
INSERT INTO branch_b02.student_contact (contact_id, student_id) VALUES (11, 'sn00000012');

-- Records of branch_b02.staff_office
INSERT INTO branch_b02.staff_office (room_id, staff_id) VALUES (4,'s000000008');
INSERT INTO branch_b02.staff_office (room_id, staff_id) VALUES (5,'s000000009');
INSERT INTO branch_b02.staff_office (room_id, staff_id) VALUES (6,'s000000010');
INSERT INTO branch_b02.staff_office (room_id, staff_id) VALUES (7,'s000000011');
INSERT INTO branch_b02.staff_office (room_id, staff_id) VALUES (8,'s000000012');
INSERT INTO branch_b02.staff_office (room_id, staff_id) VALUES (9,'s000000013');
INSERT INTO branch_b02.staff_office (room_id, staff_id) VALUES (10,'s000000014');

-- Assign random grades to all student assessments
UPDATE branch_b02.student_assessment
SET grade = ROUND(CAST((random() * 70) AS numeric), 2);

-- Update attendance records (randomly) for all sessions that have passed
UPDATE branch_b02.student_session AS ss
SET attendance_record = (
  CASE 
    WHEN RANDOM() > 0.75 THEN TRUE
    ELSE FALSE
  END
)
WHERE EXISTS (
  SELECT 1
  FROM branch_b02.session AS s
  WHERE s.session_id = ss.session_id
    AND s.session_date < CURRENT_DATE
);

-- QUERY 1: Module Attendance
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
  branch_b01.module AS m
  JOIN shared.module AS shm USING (module_id)
  JOIN branch_b01.session AS ses USING (module_id)
  LEFT JOIN (
    SELECT
      session_id,
      COUNT(*) AS total_students,
      SUM(CASE WHEN attendance_record THEN 1 ELSE 0 END) AS attending_students
    FROM branch_b01.student_session
    GROUP BY session_id
  ) AS ss_stats ON ses.session_id = ss_stats.session_id
  JOIN branch_b01.course_module AS cm USING (module_id)
  JOIN shared.course AS c USING (course_id)
WHERE
  ses.session_date < CURRENT_DATE
  OR (ses.session_date = CURRENT_DATE AND ses.session_end_time < CURRENT_TIME)
GROUP BY "Module ID", "Module Name";

-- QUERY 2: Low Performing Students
WITH lps AS (
  SELECT *
  FROM shared.get_all_low_performing_students()
)
SELECT
  lps.branch_id AS "Branch ID",
  bt.total_low_performing_students AS "Branch Total Low Performing Students",
  lps.student_id AS "Student ID",
  lps.name AS "Student Name",
  lps.email AS "Student Email",
  lps.attendance AS "Attendance %",
  lps.attendance_rating AS "Attendance Rating",
  lps.courses_failing AS "Courses Failing"
FROM
  lps
  JOIN (
    SELECT
      branch_id,
      COUNT(*) AS total_low_performing_students
    FROM lps
    GROUP BY branch_id
  ) AS bt USING (branch_id)
ORDER BY
  "Branch ID",
  "Attendance %";

-- QUERY 3: Unpaid Tuition
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
    branch_b01.student_tuition AS st
    JOIN branch_b01.tuition AS t ON st.tuition_id = t.tuition_id
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
  JOIN branch_b01.student AS s ON ts.student_id = s.student_id
ORDER BY
  ts.total_tuition_remaining DESC,
  ts.closest_tuition_deadline;

-- QUERY 4: Branch Attendance
SELECT
  b.branch_id AS "Branch ID",
  b.branch_name AS "Branch Name",
  CONCAT(ROUND(saba.avg_student_attendance, 2), '%') AS "Average Student Attendance",
  CONCAT(ROUND(saba.avg_module_attendance, 2), '%') AS "Average Module Attendance",
  CONCAT(ROUND(saba.avg_course_attendance, 2), '%') AS "Average Course Attendance",
  CONCAT(
    saba.top_module_name,
    ' (', ROUND(saba.top_module_attendance, 2), '%)'
  ) AS "Best Module Attendance",
  CONCAT(
    saba.lowest_module_name,
    ' (', ROUND(saba.lowest_module_attendance, 2), '%)'
  ) AS "Worst Module Attendance",
  CONCAT(
    saba.top_course_name,
    ' (', ROUND(saba.top_course_attendance, 2), '%)'
  ) AS "Best Course Attendance",
  CONCAT(
    saba.lowest_course_name,
    ' (', ROUND(saba.lowest_course_attendance, 2), '%)'
  ) AS "Worst Course Attendance"
FROM
  shared.analyse_branch_attendance() AS saba
  JOIN shared.branch AS b USING (branch_id)
ORDER BY b.branch_id;

-- QUERY 5: Staff Availability
WITH date_range AS (
  SELECT
    COALESCE(MIN(busy_date), CURRENT_DATE) AS start_date,
    COALESCE(MAX(busy_date), CURRENT_DATE) AS end_date
  FROM branch_b01.staff_busy
),
teaching_staff AS (
  SELECT DISTINCT s.staff_id
  FROM branch_b01.staff AS s
  JOIN branch_b01.staff_role AS sr ON s.staff_id = sr.staff_id
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
      FROM branch_b01.staff_busy AS sb
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
  branch_b01.staff AS s
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