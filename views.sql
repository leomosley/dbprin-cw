/* CREATE BRANCH SPECIFIC VIEWS */
-- View to show each students attendance percentages
CREATE OR REPLACE VIEW branch_b01.student_attendance AS 
WITH student_details AS (
  SELECT 
    student_id,
    CONCAT_WS(' ', student_fname, student_lname) AS full_name,
    student_attendance
  FROM branch_b01.student
)
SELECT 
  sd.student_id AS "Student ID",
  sd.full_name AS "Student Name",
  sd.student_attendance AS "Attendance %"
FROM student_details sd
ORDER BY "Student ID";

-- View to show the average attendance percentage for each module
CREATE OR REPLACE VIEW branch_b01.module_attendance AS 
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

-- View to show the average attendance percentage of each course
CREATE OR REPLACE VIEW branch_b01.course_attendance AS 
SELECT
  c.course_id AS "Course ID",
  shc.course_name AS "Course Name",
  CONCAT_WS(' ', stf.staff_fname, stf.staff_lname) AS "Course Coordinator",
  ROUND(
    AVG(ma."Module Attendance %"), 2
  ) AS "Course Attendance %"
FROM 
  branch_b01.course AS c
  JOIN branch_b01.course_module AS cm USING (course_id)
  JOIN branch_b01.module_attendance AS ma ON cm.module_id = ma."Module ID"
  JOIN shared.course AS shc USING (course_id)
  JOIN branch_b01.staff AS stf USING (staff_id)
GROUP BY "Course ID", "Course Name", "Course Coordinator";


-- View to show the students tuition details
CREATE OR REPLACE VIEW branch_b01.student_tuition_details AS
SELECT 
  st.student_id AS "Student ID",
  CONCAT_WS(' ', s.student_fname, s.student_lname) AS "Student Name",
  t.tuition_id AS "Tuition ID",
  t.tuition_amount AS "Total Tuition",
  t.tuition_paid AS "Tuition Paid",
  t.tuition_remaining AS "Tuition Remaining",
  t.tuition_remaining_perc AS "Remaining Percentage %",
  t.tuition_deadline AS "Tuition Deadline"
FROM 
  branch_b01.student_tuition AS st
  JOIN branch_b01.student AS s USING (student_id)
  JOIN branch_b01.tuition AS t USING (tuition_id)
ORDER BY 
  "Student ID", "Tuition ID";

-- View to show students who have outstanding tuition passed their deadline
CREATE OR REPLACE VIEW branch_b01.unpaid_tuition_students AS
SELECT 
  "Student ID",
  "Student Name",
  "Tuition ID",
  "Total Tuition",
  "Tuition Paid",
  "Tuition Remaining",
  "Tuition Deadline"
FROM branch_b01.student_tuition_details
WHERE 
  "Tuition Deadline" < CURRENT_DATE 
  AND "Tuition Remaining" > 0
ORDER BY "Tuition Deadline";

-- View to show all upcoming session times and dates for each room in branch
CREATE OR REPLACE VIEW branch_b01.room_session_times AS
SELECT 
  r.room_id AS "Room ID",
  r.room_alt_name AS "Room Name",
  rt.type_name AS "Room Type",
  s.session_start_time AS "Session Start Time",
  s.session_end_time AS "Session End Time",
  s.session_date AS "Session Date"
FROM 
  branch_b01.session AS s
  JOIN branch_b01.room AS r USING (room_id)
  JOIN shared.room_type AS rt USING (room_type_id)
WHERE 
  s.session_date > CURRENT_DATE
  OR (s.session_date = CURRENT_DATE AND s.session_start_time > CURRENT_TIME) 
ORDER BY r.room_id, s.session_date, s.session_start_time;

-- Function to determine if specific room is free at a specific time and date
CREATE OR REPLACE FUNCTION branch_b01.is_room_available(
  p_room_id INT,
  p_requested_time TIME,
  p_requested_date DATE
) 
RETURNS BOOLEAN AS $$
DECLARE
  room_session_count INT;
BEGIN
  -- Enforce time range between 9 AM and 6 PM
  IF p_requested_time < '09:00:00'::TIME OR p_requested_time > '18:00:00'::TIME THEN
    RAISE EXCEPTION 'Requested time must be between 09:00 and 18:00';
  END IF;
  -- Enforce the date to be a weekday (no weekends)
  IF EXTRACT(DOW FROM p_requested_date) IN (0, 6) THEN  -- 0 = Sunday, 6 = Saturday
    RAISE EXCEPTION 'Requested date cannot be a weekend';
  END IF;
  -- Check if the room is already booked for the given time and date using the view
  SELECT COUNT(*)
  INTO room_session_count
  FROM branch_b01.room_session_times
  WHERE 
    "Room ID" = p_room_id
    AND "Session Date" = p_requested_date
    AND (
      ("Session Start Time" < p_requested_time AND "Session End Time" > p_requested_time)  -- requested time overlaps with an ongoing session
      OR
      ("Session Start Time" < (p_requested_time + interval '1 minute') AND "Session End Time" > (p_requested_time + interval '1 minute'))  -- requested time overlaps with session start time
    );
  IF room_session_count > 0 THEN
    RETURN FALSE;
  ELSE
    RETURN TRUE;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to find available time slots for a specific room on a specific date
CREATE OR REPLACE FUNCTION branch_b01.get_day_available_room_time(
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
    FROM generate_series(0, (EXTRACT(HOUR FROM time_slot_end - time_slot_start) * 60 / 60) - 1) i
    WHERE time_slot_start + (i * slot_interval) >= '09:00:00' AND time_slot_start + (i * slot_interval) <= '18:00:00'
  LOOP
    -- Use the previously created function to check availability
    IF branch_b01.is_room_available(p_room_id, time_slot_start, p_requested_date) THEN
      -- If the room is available, return the time slot
      RETURN QUERY SELECT time_slot_start;
    END IF;
  END LOOP;
  RETURN;
END;
$$ LANGUAGE plpgsql;

/* CREATE SHARED VIEWS */
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