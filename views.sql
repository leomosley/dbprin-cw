/* SHARED INSERTS */

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
  ROUND(
    (bt.total_low_performing_students * 100.0) / ts.total_students_in_branch, 
    2
  ) AS "Percentage of Students Failing",
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
  JOIN (
    SELECT 
      branch_id, 
      COUNT(*) AS total_students_in_branch
    FROM lps
    GROUP BY branch_id
  ) AS ts USING (branch_id)
ORDER BY 
  "Branch ID",
  "Attendance %";

/* BRANCH SPECIFIC VIEWS */

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