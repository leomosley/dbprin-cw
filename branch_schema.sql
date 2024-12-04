-- -------------------------
-- Table structure for STAFF
-- -------------------------
CREATE TABLE branch_.staff (
  staff_id CHAR(10) DEFAULT (
    CONCAT('S', shared.generate_uid(9))
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

-- ------------------------------
-- Table structure for STAFF_ROLE
-- ------------------------------
CREATE TABLE branch_.staff_role (
  staff_id CHAR(10) NOT NULL,
  role_id INT NOT NULL,
  PRIMARY KEY (staff_id, role_id),
  FOREIGN KEY (staff_id) REFERENCES branch_.staff (staff_id),
  FOREIGN KEY (role_id) REFERENCES shared.role (role_id)
);

-- ------------------------------
-- Table structure for DEPARTMENT
-- ------------------------------
CREATE TABLE branch_.department (
  dep_id CHAR(7) NOT NULL,
  staff_id CHAR(10) NOT NULL,
  PRIMARY KEY (dep_id),
  FOREIGN KEY (dep_id) REFERENCES shared.department (dep_id),
  FOREIGN KEY (staff_id) REFERENCES branch_.staff (staff_id)
);

-- --------------------------
-- Table structure for COURSE
-- --------------------------
CREATE TABLE branch_.course (
  course_id CHAR(7) NOT NULL,
  staff_id CHAR(10) NOT NULL,
  PRIMARY KEY (course_id),
  FOREIGN KEY (course_id) REFERENCES shared.course (course_id),
  FOREIGN KEY (staff_id) REFERENCES branch_.staff (staff_id)
);

-- -------------------------------------
-- Table structure for DEPARTMENT_COURSE
-- -------------------------------------
CREATE TABLE shared.department_course (
  dep_id CHAR(7) NOT NULL,
  course_id CHAR(7) NOT NULL,
  PRIMARY KEY (dep_id, course_id),
  FOREIGN KEY (dep_id) REFERENCES branch_.department (dep_id),
  FOREIGN KEY (course_id) REFERENCES branch_.course (course_id)
);

-- --------------------------
-- Table structure for MODULE
-- --------------------------
CREATE TABLE branch_.module (
  module_id CHAR(10) NOT NULL,
  staff_id CHAR(10) NOT NULL,
  PRIMARY KEY (module_id),
  FOREIGN KEY (module_id) REFERENCES shared.module (module_id),
  FOREIGN KEY (staff_id) REFERENCES branch_.staff (staff_id)
);

-- ----------------------------------
-- Table structure for COURSE_MODULE
-- ----------------------------------
CREATE TABLE branch_.module (
  module_id CHAR(10) NOT NULL,
  course_id CHAR(7) NOT NULL,
  PRIMARY KEY (module_id, course_id),
  FOREIGN KEY (module_id) REFERENCES branch_.module (module_id),
  FOREIGN KEY (course_id) REFERENCES branch_.course (course_id)
);

-- ---------------------------
-- Table structure for STUDENT
-- ---------------------------

-- ----------------------------------
-- Table structure for STUDENT_COURSE
-- ----------------------------------

-- ----------------------------------
-- Table structure for STUDENT_MODULE
-- ----------------------------------

-- ------------------------------
-- Table structure for ASSESSMENT
-- ------------------------------

-- --------------------------------------
-- Table structure for STUDENT_ASSESSMENT
-- --------------------------------------

-- ---------------------------
-- Table structure for TUITION
-- ---------------------------

-- -----------------------------------
-- Table structure for STUDENT_TUITION
-- -----------------------------------

-- -----------------------------------
-- Table structure for TUITION_PAYMENT
-- -----------------------------------

-- ------------------------------------
-- Table structure for STAFF_DEPARTMENT
-- ------------------------------------

-- ----------------------------
-- Table structure for BUILDING
-- ----------------------------

-- ------------------------
-- Table structure for ROOM
-- ------------------------

-- ---------------------------------
-- Table structure for ROOM_FACILITY
-- ---------------------------------

-- ---------------------------
-- Table structure for SESSION
-- ---------------------------

-- ---------------------------------
-- Table structure for STAFF_SESSION
-- ---------------------------------

-- -----------------------------------
-- Table structure for STUDENT_SESSION
-- -----------------------------------

-- ---------------------------------
-- Table structure for STAFF_CONTACT
-- ---------------------------------

-- -----------------------------------
-- Table structure for STUDENT_CONTACT
-- -----------------------------------

-- --------------------------------
-- Table structure for STAFF_OFFICE
-- --------------------------------

-- ------------------------------
-- Table structure for ASSIGNMENT
-- ------------------------------

-- ------------------------------------
-- Table structure for STAFF_ASSIGNMENT
-- ------------------------------------