/* CREATE SHARED ROLES */
-- Student role
CREATE ROLE student_role NOLOGIN;

-- Teaching staff role
CREATE ROLE teaching_staff_role NOLOGIN;

GRANT SELECT ON ALL TABLES IN SCHEMA shared TO teaching_staff_role;

-- Admin staff role
CREATE ROLE admin_staff_role NOLOGIN;

GRANT SELECT ON ALL TABLES IN SCHEMA shared TO admin_staff_role;

/* GRANT BRANCH SPECIFIC ACCESS */
GRANT USAGE ON SCHEMA branch_b01 TO student_role;
GRANT SELECT ON ALL TABLES IN SCHEMA branch_b01 TO student_role;
GRANT SELECT ON ALL VIEWS IN SCHEMA branch_b01 TO student_role;

GRANT USAGE ON SCHEMA branch_b01 TO teaching_staff_role;

GRANT SELECT ON branch_b01.session, branch_b01.student, branch_b01.module TO teaching_staff_role;
GRANT SELECT ON branch_b01.student_session TO teaching_staff_role;

GRANT UPDATE (attendance_record) ON branch_b01.student_session TO teaching_staff_role;

GRANT USAGE ON SCHEMA branch_b01 TO admin_staff_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA branch_b01 TO admin_staff_role;

REVOKE SELECT ON branch_b01.student.student_email, branch_b01.student.student_address FROM admin_staff_role;

/* BRANCH SPECIFIC POLICIES ON SHARED TABLES */
-- Course Policy
CREATE POLICY course_student_view_policy
ON shared.course
FOR SELECT
USING (course_id IN (SELECT course_id FROM branch_b01.student_course WHERE student_id = current_user));

-- Module Policy
CREATE POLICY module_student_view_policy
ON shared.module
FOR SELECT
USING (module_id IN (SELECT module_id FROM branch_b01.student_module WHERE student_id = current_user));

CREATE POLICY module_staff_view_policy
ON shared.module
FOR SELECT
USING (module_id IN (SELECT module_id FROM branch_b01.staff_module WHERE staff_id = current_user));

-- Assessment Policy
CREATE POLICY assessment_student_view_policy
ON shared.assessment
FOR SELECT
USING (module_id IN (SELECT module_id FROM branch_b01.student_module WHERE student_id = current_user));

CREATE POLICY assessment_staff_manage_policy
ON shared.assessment
FOR ALL
USING (module_id IN (SELECT module_id FROM branch_b01.staff_module WHERE staff_id = current_user));

-- Emergency Contacy Policy
CREATE POLICY emergency_contact_student_view_policy
ON shared.emergency_contact
FOR SELECT
USING (contact_id IN (SELECT contact_id FROM branch_b01.student_contact WHERE student_id = current_user));