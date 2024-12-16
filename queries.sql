/* 
  QUERY 1: Module Attendance 
*/
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

/* 
  QUERY 2: Low Performing Students 
*/
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

/* 
  QUERY 3: Unpaid Tuition
*/
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

/* 
  QUERY 4: Branch Attendance
*/
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

/* 
  QUERY 5: Staff Availability
*/
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