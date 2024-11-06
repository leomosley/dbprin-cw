-- -------------------
-- Records of STUDENT
-- -------------------
INSERT INTO student (student_personal_email, student_fname, student_mname, student_lname, student_pronouns, student_addr1, student_addr2, student_city, student_postcode, student_landline, student_mobile, student_dob, student_attendance)
VALUES
  ('alex.braun@gmail.com', 'Alex', NULL, 'Braun', 'He/Him', '123 Main Street', 'Mayfair', 'London', 'SW1A 1AA', '0201234570', '07891234572', '1995-05-15', 0.00),
  ('jane.smith@outlook.com', 'Jane', NULL, 'Smith', 'She/Her', '456 Park Avenue', NULL, 'Manchester', 'M1 1AA', '0161234569', '07987654323', '1994-10-20', 0.00),
  ('JOHN.doe@yahoo.com', 'John', 'James', 'Doe', 'He/Him', '123 Main Street', 'Kensington', 'London', 'SW1A 1AA', '0201234571', '07891234573', '1995-05-15', 0.00),
  ('emily.johnson@mail.co.uk', 'Emily', NULL, 'Johnson', 'She/Her', '789 Oak Lane', NULL, 'Birmingham', 'B1 1AA', '0123456789', '07712345678', '1997-08-18', 0.00),
  ('michael.brown@example.com', 'Michael', 'Luke', 'Brown', 'He/Him', '1010 Maple Street', NULL, 'Edinburgh', 'EH1 1AA', '0131234567', '07723456789', '1996-12-03', 0.00),
  ('emma.williams@example.com', 'Emma', NULL, 'Williams', 'She/Her', '789 Cedar Street', NULL, 'London', 'SW1A 2AB', '0203456789', '07892345678', '1999-04-15', 0.00),
  ('alexander.brown@example.com', 'Alexander', 'James', 'Brown', 'He/Him', '456 Birch Avenue', NULL, 'Manchester', 'M1 2AB', '0163456789', '07998765432', '1998-08-20', 0.00),
  ('olivia.taylor@example.com', 'Olivia', NULL, 'Taylor', 'She/Her', '101 Elm Street', NULL, 'Glasgow', 'G2 1AB', '0142345671', '07871234571', '2000-02-25', 0.00),
  ('will.thomas@example.com', 'William', 'John', 'Thomas', 'He/Him', '789 Oak Lane', NULL, 'Bristol', 'BS2 1AB', '0113456780', '07912345681', '1997-06-30', 0.00);

-- -------------------
-- Records of TUITION
-- -------------------
INSERT INTO tuition (tuition_amount, tuition_paid, tuition_remaining, tuition_remaining_perc, tuition_deadline)
VALUES
  (2800.00, 0, 2800.00, 0, '2025-07-01'),
  (2900.00, 0, 2900.00, 0, '2025-08-05'),
  (3000.00, 0, 3000.00, 0, '2025-07-10'),
  (3100.00, 0, 3100.00, 0, '2025-08-15'),
  (3200.00, 0, 3200.00, 0, '2025-07-20'),
  (3300.00, 0, 3300.00, 0, '2025-08-25'),
  (3400.00, 0, 3400.00, 0, '2025-07-30'),
  (3500.00, 0, 3500.00, 0, '2025-08-05'),
  (3600.00, 0, 3600.00, 0, '2025-07-10'),
  (1500.00, 0, 1500.00, 0, '2025-07-31');

-- ---------------------------
-- Records of STUDENT_TUITION
-- ---------------------------
INSERT INTO student_tuition (student_id, tuition_id)
VALUES
  (1, 1),
  (2, 2),
  (3, 3),
  (4, 4),
  (5, 5),
  (6, 6),
  (7, 7),
  (8, 8),
  (9, 9),
  (9, 10);

-- ---------------------------
-- Records of TUITION_PAYMENT
-- ---------------------------
INSERT INTO tuition_payment (tuition_id, tuition_payment_amount, tuition_payment_date, tuition_payment_method)
VALUES
  (1, 300.00, '2025-03-15', 'Bank Transfer'),
  (2, 200.00, '2025-03-20', 'Bank Transfer'),
  (3, 400.00, '2025-04-10', 'Direct Debit'),
  (4, 600.00, '2025-04-20', 'Direct Debit'),
  (5, 500.00, '2025-05-10', 'Direct Debit'),
  (6, 200.00, '2025-05-20', 'Direct Debit'),
  (7, 700.00, '2025-05-10', 'Direct Debit'),
  (8, 300.00, '2025-05-20', 'Direct Debit'),
  (9, 400.00, '2025-05-10', 'Bank Transfer'),
  (10, 600.00, '2025-05-20', 'Bank Transfer'),
  (1, 800.00, '2025-05-10', 'Debit Card'),
  (2, 300.00, '2025-05-20', 'Debit Card'),
  (3, 500.00, '2025-05-10', 'Debit Card'),
  (4, 400.00, '2025-05-20', 'Credit Card'),
  (5, 200.00, '2025-05-10', 'Bank Transfer');

-- -----------------------
-- Records of DEPARTMENTS
-- -----------------------
INSERT INTO departments (dep_name, dep_type, dep_description)
VALUES
  ('Arts', 'Educational', 'Department of Arts'),
  ('Humanities', 'Educational', 'Department of Humanities'),
  ('Computing', 'Educational', 'Department of Computing'),
  ('Mathematics', 'Educational', 'Department of Mathematics'),
  ('Science', 'Educational', 'Department of Science'),
  ('Technology', 'Educational', 'Department of Technology'),
  ('Engineering', 'Educational', 'Department of Engineering'),
  ('Vocational Training', 'Educational', 'Department of Vocational Training'),
  ('Finance', 'Administrative', NULL),
  ('Human Resources', 'Administrative', NULL);
  
-- -----------------
-- Records of BRANCH
-- -----------------
INSERT INTO branch (branch_name, branch_status, branch_addr1, branch_addr2, branch_postcode, branch_contact_number, branch_email)
VALUES
  ('SES London', 'Open', '123 High Street', 'Westminster', 'SW1A 1AA', '020 7946 0958', 'london@ses.edu.org'),
  ('SES Manchester', 'Open', '45 Oxford Road', 'Manchester City Centre', 'M1 5QA', '0161 306 6000', 'manchester@ses.edu.org'),
  ('SES Birmingham', 'Closed', '200 Broad Street', 'Birmingham', 'B1 2HQ', '0121 643 2233', 'birmingham@ses.edu.org'),
  ('SES Edinburgh', 'Open', '7 George Street', 'Edinburgh', 'EH2 2QL', '0131 622 8000', 'edinburgh@ses.edu.org'),
  ('SES Bristol', 'Closed', '25 Park Street', 'Bristol', 'BS1 5NH', '0117 928 9000', 'bristol@ses.edu.org');

-- ----------------------------
-- Records of BRANCH_DEPARTMENT
-- ----------------------------
INSERT INTO branch_department (branch_id, dep_id)
VALUES
  (1, 1),
  (1, 2),
  (1, 5),
  (1, 9),
  (1, 10),
  (2, 3),
  (2, 4),
  (2, 5),
  (2, 6),
  (2, 7),
  (2, 9),
  (2, 10),
  (3, 8),
  (3, 9),
  (3, 10),
  (4, 1),
  (4, 2),
  (4, 5),
  (4, 6),
  (4, 9),
  (4, 10),
  (5, 2),
  (5, 3),
  (5, 4),
  (5, 5),
  (5, 9),
  (5, 10);

-- ----------------
-- Records of STAFF
-- ----------------
INSERT INTO staff (staff_fname, staff_mname, staff_lname, staff_title, staff_addr1, staff_addr2, staff_city, staff_postcode, staff_personal_email, staff_landline, staff_mobile, staff_dob)
VALUES
('John', NULL, 'Smith', 'Dr', '789 Elm Street', NULL, 'London', 'SW1A 2AA', 'john.smith@example.com', '0201234567', '07891234567', '1980-03-25'),
('Jane', NULL, 'Doe', 'Mrs', '987 Oak Avenue', NULL, 'Manchester', 'M1 2AA', 'jAne.doe@example.com', '0161234567', '07987654321', '1975-07-10'),
('Laura', 'Lily', 'Taylor', 'Ms', '456 Elm Street', NULL, 'Glasgow', 'G1 1AA', 'laura.taylor@example.com', '0201234512', '07891232567', '1985-05-20'),
('David', NULL, 'Clark', 'Dr', '789 Pine Avenue', NULL, 'Bristol', 'BS1 1AA', 'david.clark@example.com', '0123456789', '07712345678', '1978-09-12'),
('Michael', NULL, 'Johnson', 'Dr', '123 Cedar Street', NULL, 'London', 'SW1A 2AA', 'michael.johnson@example.com', '0131234567', '07723456789', '1983-02-15'),
('Emily', 'Anne', 'Harris', 'Mrs', '456 Birch Avenue', NULL, 'Manchester', 'M1 2AB', 'emily.harris@example.com', '0203456789', '07892345678', '1977-11-30'),
('Daniel', 'James', 'Anderson', 'Mr', '789 Oak Lane', NULL, 'Glasgow', 'G2 1AB', 'dan.anderson@example.com', '0163456789', '07998765432', '1982-06-25'),
('Sophia', NULL, 'Wilson', 'Ms', '101 Maple Street', NULL, 'Bristol', 'BS2 1AB', 'sophia.wilson@example.com', '0142345678', '07871234567', '1980-09-18'),
('Oliver', 'Robert', 'Martin', 'Mr', '789 Elm Street', NULL, 'London', 'SW1A 1AA', 'oliver.martin@example.com', '0113456789', '07912345678', '1975-04-10'),
('Amelia', NULL, 'Thompson', 'Dr', '456 Oak Avenue', NULL, 'Manchester', 'M1 1AA', 'amelia.thompson@example.com', '0202345678', '07891234568', '1978-08-05'),
('Ethan', 'William', 'White', 'Dr', '789 Pine Avenue', NULL, 'Glasgow', 'G1 1AA', 'ethan.white@example.com', '0162345679', '07987654322', '1983-11-20'),
('Ava', NULL, 'Davis', 'Mrs', '101 Cedar Street', NULL, 'Bristol', 'BS1 1AA', 'ava.davis@example.com', '0141234578', '07876543210', '1981-03-15'),
('Noah', 'Edward', 'Wilson', 'Dr', '123 Birch Avenue', NULL, 'London', 'SW1A 2AB', 'noah.wilson@example.com', '0203456790', '07892345679', '1976-06-30'),
('Isabella', NULL, 'Harris', 'Dr', '456 Maple Street', NULL, 'Manchester', 'M1 2AB', 'isabella.harris@example.com', '0163456791', '07998765433', '1979-09-25'),
('James', 'Alexander', 'Brown', 'Dr', '789 Oak Lane', NULL, 'Glasgow', 'G2 1AB', 'james.brown@example.com', '0112345670', '07871234568', '1984-12-10'),
('Charlotte', NULL, 'Wilson', 'Dr', '101 Elm Street', NULL, 'Bristol', 'BS2 1AB', 'charlotte.wilson@example.com', '0142345679', '07876543211', '1977-02-05'),
('Benjamin', 'Michael', 'Lee', 'Mr', '789 Pine Avenue', NULL, 'London', 'SW1A 1AA', 'benjamin.lee@example.com', '0112345671', '07901234569', '1982-05-20'),
('Mia', NULL, 'Roberts', 'Dr', '456 Cedar Street', NULL, 'Manchester', 'M1 1AA', 'mia.roberts@example.com', '0201234568', '07891234569', '1975-08-15'),
('William', 'Daniel', 'Thomas', 'Dr', '789 Elm Street', NULL, 'Glasgow', 'G1 1AA', 'william.thomas@example.com', '0161234568', '07987554322', '1980-10-30'),
('Evelyn', NULL, 'Evans', 'Mrs', '101 Oak Avenue', NULL, 'Bristol', 'BS1 1AA', 'evelyn.evans@example.com', '0142348579', '07872234568', '1973-11-25'),
('Sophie', NULL, 'Roberts', 'Dr', '123 Maple Street', NULL, 'London', 'SW1A 2AA', 'sophie.roberts@example.com', '0113256780', '07912345679', '1988-09-15'),
('Jack', 'William', 'Harris', 'Mr', '456 Birch Avenue', NULL, 'Manchester', 'M1 2AB', 'jack.harris@example.com', '0142345670', '07871234570', '1977-12-20'),
('Emily', 'Grace', 'Wilson', 'Dr', '789 Oak Lane', NULL, 'Glasgow', 'G2 1AB', 'emily.wilson@example.com', '0113256781', '07912345680', '1982-06-25'),
('Daniel', 'Thomas', 'Anderson', 'Mr', '101 Cedar Street', NULL, 'Bristol', 'BS1 1AB', 'daniel.anderson@example.com', '0201234569', '07891234571', '1979-03-30');


-- ----------------------------
-- Records of EMERGENCY_CONTACT
-- ----------------------------
INSERT INTO emergency_contact (contact_email, contact_phone, contact_fname, contact_wname, contact_lname, contact_addr1, contact_addr2, contact_city, contact_postcode, contact_relationship)
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

-- ------------------------
-- Records of STAFF_CONTACT
-- ------------------------
INSERT INTO staff_contact (contact_id, staff_id)
VALUES
  (13, 1),
  (14, 2),
  (15, 3),
  (16, 4),
  (17, 5),
  (18, 6),
  (19, 7),
  (20, 8),
  (21, 9),
  (22, 10),
  (23, 11),
  (24, 12),
  (25, 13),
  (26, 14),
  (27, 15),
  (28, 16),
  (29, 17),
  (30, 18),
  (31, 19),
  (32, 20),
  (33, 21);

-- --------------------------
-- Records of STUDENT_CONTACT
-- --------------------------
INSERT INTO student_contact (contact_id, student_id)
VALUES
  (1, 1),
  (2, 2),
  (3, 3),
  (4, 4),
  (5, 5),
  (6, 6),
  (7, 7),
  (8, 8),
  (9, 9),
  (10, 10),
  (11, 11),
  (12, 12);

-- ---------------------------
-- Records of STAFF_DEPARTMENT
-- ---------------------------
INSERT INTO staff_department (staff_id, dep_id)
VALUES
  (1, 1),
  (2, 1),
  (4, 1),
  (5, 1),
  (6, 2),
  (7, 2),
  (8, 2),
  (10, 2),
  (11, 3),
  (12, 3),
  (13, 3),
  (14, 3),
  (15, 3),
  (16, 4),
  (18, 4),
  (19, 4),
  (20, 4),
  (3, 9),
  (9, 8),
  (17, 9),
  (10, 9);

-- -------------------
-- Records of BUILDING
-- -------------------
INSERT INTO building (branch_id, building_name, building_alt_name, building_type, building_addr1, building_addr2, building_city, building_postcode, building_country)
VALUES
  (1, 'Turing Hall', 'STEM Innovation Centre', 'Educational', '12 Science Way', 'South Bank', 'London', 'SW1A 1AA', 'United Kingdom'),
  (1, 'Ada Lovelace Building', 'Administrative Office', 'Administrative', '98 King Street', 'Mayfair', 'London', 'SW1A 1AB', 'United Kingdom'),
  (2, 'Anthony Burgess Hall', 'Humanities and Arts Centre', 'Educational', '21 University Street', NULL, 'Manchester', 'M1 1AA', 'United Kingdom'),
  (2, 'Pankhurst Building', 'Finance and HR Office', 'Administrative', '15 Queens Avenue', NULL, 'Manchester', 'M1 2AB', 'United Kingdom'),
  (3, 'James Watt Building', 'Technology and Science Wing', 'Educational', '10 Research Road', NULL, 'Birmingham', 'B1 1AA', 'United Kingdom'),
  (3, 'Priestley House', 'Administrative Block', 'Administrative', '22 Green Park', NULL, 'Birmingham', 'B1 1BB', 'United Kingdom'),
  (4, 'Adam Smith Centre', 'Vocational Skills Hub', 'Educational', '5 Industry Lane', NULL, 'Edinburgh', 'EH1 1AA', 'United Kingdom'),
  (5, 'Kelvin Science Building', 'STEM Centre', 'Educational', '3 Knowledge Crescent', NULL, 'Glasgow', 'G2 1AB', 'United Kingdom'),
  (5, 'Mackintosh Arts Building', 'Humanities and Arts Wing', 'Educational', '5 University Avenue', NULL, 'Glasgow', 'G2 1AD', 'United Kingdom'),
  (5, 'Adam Smith Administration Block', NULL, 'Administrative', '8 College Gardens', NULL, 'Glasgow', 'G2 2AB', 'United Kingdom');

-- ---------------
-- Records of ROOM
-- ---------------
INSERT INTO room (building_id, room_name, room_alt_name, room_type, room_capacity, room_floor)
VALUES
  (1, 'Arts Building 1.01', 'AB 1.01', 'Lecture Theatre', 100, 1),
  (1, 'Arts Building 1.02', 'AB 1.02', 'Computer Lab', 40, 1),
  (1, 'Arts Building 1.03', 'AB 1.03', 'Creative Arts Studio', 30, 1),
  (1, 'Arts Building 1.04', 'AB 1.04', 'Practical Room', 25, 1),
  (1, 'Arts Building 1.05', 'AB 1.05', 'Office', 1, 1),
  (1, 'Arts Building 1.06', 'AB 1.06', 'Office', 1, 1),
  (1, 'Arts Building 1.07', 'AB 1.07', 'Office', 1, 1),
  (1, 'Arts Building 1.08', 'AB 1.08', 'Office', 1, 1),
  (1, 'Arts Building 1.09', 'AB 1.09', 'Office', 1, 1),
  (1, 'Arts Building 2.01', 'AB 2.01', 'Office', 1, 2),
  (1, 'Arts Building 2.02', 'AB 2.02', 'Office', 1, 2),
  (1, 'Arts Building 2.03', 'AB 2.03', 'Office', 1, 2),
  (1, 'Arts Building 2.04', 'AB 2.04', 'Office', 1, 2),
  (1, 'Arts Building 2.05', 'AB 2.05', 'Music Room', 20, 2),
  (1, 'Arts Building 2.06', 'AB 2.06', 'Practical Room', 35, 2),
  (1, 'Arts Building 2.07', 'AB 2.07', 'Art Studio', 25, 2),
  (2, 'Turing Hall 1.01', 'TH 1.01', 'Computer Lab', 40, 1),
  (2, 'Turing Hall 1.02', 'TH 1.02', 'Office', 1, 1),
  (2, 'Turing Hall 1.03', 'TH 1.03', 'Office', 1, 1),
  (2, 'Turing Hall 1.04', 'TH 1.04', 'Office', 1, 1),
  (2, 'Turing Hall 1.05', 'TH 1.05', 'Office', 1, 1),
  (2, 'Turing Hall 2.01', 'TH 2.01', 'Office', 1, 2),
  (2, 'Turing Hall 2.02', 'TH 2.02', 'Computer Lab', 40, 2),
  (2, 'Turing Hall 2.03', 'TH 2.03', 'Office', 1, 2),
  (2, 'Turing Hall 2.04', 'TH 2.04', 'Computer Lab', 40, 2),
  (3, 'Newton Science Lab 1.01', 'NSL 1.01', 'Practical Room', 35, 1),
  (3, 'Newton Science Lab 1.02', 'NSL 1.02', 'Biology Lab', 30, 1),
  (3, 'Newton Science Lab 1.03', 'NSL 1.03', 'Physics Lab', 30, 1),
  (3, 'Newton Science Lab 2.01', 'NSL 2.01', 'Chemistry Lab', 30, 2),
  (3, 'Newton Science Lab 2.02', 'NSL 2.02', 'Office', 1, 2),
  (3, 'Newton Science Lab 2.03', 'NSL 2.03', 'Office', 1, 2),
  (3, 'Newton Science Lab 2.04', 'NSL 2.04', 'Office', 1, 2),
  (4, 'Humanities Building 1.01', 'HB 1.01', 'Lecture Theatre', 100, 1),
  (4, 'Humanities Building 1.02', 'HB 1.02', 'Seminar Room', 20, 1),
  (4, 'Humanities Building 1.03', 'HB 1.03', 'Office', 1, 1),
  (4, 'Humanities Building 2.01', 'HB 2.01', 'Office', 1, 2),
  (4, 'Humanities Building 2.02', 'HB 2.02', 'Office', 1, 2),
  (4, 'Humanities Building 2.03', 'HB 2.03', 'Practical Room', 25, 2),
  (5, 'Maths Building 1.01', 'MB 1.01', 'Lecture Theatre', 100, 1),
  (5, 'Maths Building 1.02', 'MB 1.02', 'Statistics Lab', 30, 1),
  (5, 'Maths Building 1.03', 'MB 1.03', 'Office', 1, 1),
  (5, 'Maths Building 2.01', 'MB 2.01', 'Office', 1, 2),
  (5, 'Maths Building 2.02', 'MB 2.02', 'Office', 1, 2),
  (6, 'Engineering Building 1.01', 'EB 1.01', 'Practical Room', 40, 1),
  (6, 'Engineering Building 1.02', 'EB 1.02', 'Workshop Room', 50, 1),
  (6, 'Engineering Building 1.03', 'EB 1.03', 'Office', 1, 1),
  (6, 'Engineering Building 2.01', 'EB 2.01', 'Office', 1, 2),
  (6, 'Engineering Building 2.02', 'EB 2.02', 'Workshop Room', 50, 2),
  (7, 'Vocational Training Building 1.01', 'VTB 1.01', 'Office', 1, 1),
  (7, 'Vocational Training Building 1.02', 'VTB 1.02', 'Practical Room', 35, 1),
  (7, 'Vocational Training Building 1.03', 'VTB 1.03', 'Office', 1, 1),
  (7, 'Vocational Training Building 2.01', 'VTB 2.01', 'Vocational Lab', 30, 2);

-- ----------------------------
-- Table structure for FACILITY
-- ----------------------------
INSERT INTO facility (facility_total_quantity, facility_name, facility_description, facility_notes)
VALUES
  (30, 'Easel Sets', 'Sets of easels for painting and drawing.', 'Used in Creative Arts Studio 1.'),
  (40, 'Desktop Computers', 'High-performance desktop computers with programming software.', 'Available in Computer Lab 1.01 and Turing Hall Computer Lab.'),
  (40, 'Laptops', 'Laptops for student use in practical sessions.', 'Available in Computer Lab 2 and Statistics Lab.'),
  (10, 'Microscopes', 'Microscopes for biology labs.', 'Available in Biology Lab 1.'),
  (20, 'Physics Experiment Kits', 'Kits including materials for common physics experiments.', 'Available in Physics Lab 1.'),
  (30, 'Chemistry Glassware Sets', 'Sets of beakers, flasks, and other glassware for chemistry experiments.', 'Available in Chemistry Lab 1.'),
  (20, 'Statistical Analysis Software Licenses', 'Licenses for software such as SPSS or R for statistics.', 'Available in Statistics Lab 1.'),
  (25, '3D Printers', '3D printers for engineering and design projects.', 'Available in Engineering Workshop 1.'),
  (30, 'Hand Tools', 'General hand tools for engineering practicals including screwdrivers and wrenches.', 'Available in Engineering Workshop 1.'),
  (30, 'Vocational Training Equipment', 'Tools for carpentry, plumbing, and electrical work.', 'Available in Vocational Lab 1.'),
  (20, 'Projector Systems', 'Projectors for presentations in seminar rooms.', 'Available in Humanities Seminar Room.'),
  (40, 'Acoustic Instruments', 'Guitars, violins, and percussion instruments for music education.', 'Available in Music Room 1.'),
  (30, 'Digital Cameras', 'Cameras for photography and media courses.', 'Available in Photography Studio 1.'),
  (20, 'Animation Software', 'Software for 2D and 3D animation for creative arts.', 'Available in Animation Lab.'),
  (15, 'Robotics Kits', 'Kits for building and programming robots.', 'Available in Robotics Lab.'),
  (40, 'Whiteboards', 'Large whiteboards for collaborative work.', 'Available in various classrooms including Engineering Workshop and Humanities Seminar Room.'),
  (10, 'Art Supplies', 'Paints, brushes, and canvases for student projects.', 'Available in Creative Arts Studio 1.'),
  (5, 'CNC Machines', 'Computer-controlled cutting machines for precise engineering work.', 'Available in Engineering Workshop 2.'),
  (20, 'Computer Aided Design (CAD) Software Licenses', 'Licenses for CAD software used in engineering and architecture.', 'Available in Engineering Lab.'),
  (50, 'Textbooks', 'Variety of textbooks for various subjects.', 'Available in Humanities Seminar Room and various labs.'),
  (10, 'Artistic Sculpting Tools', 'Tools for sculpting in various mediums.', 'Available in Creative Arts Studio 1.');

-- ---------------------------------
-- Table structure for ROOM_FACILITY
-- ---------------------------------
INSERT INTO room_facility (room_id, facility_id, quantity)
VALUES
  (1, 1, 30),
  (2, 2, 40),
  (3, 1, 25),
  (4, 1, 10),
  (5, 1, 1),
  (6, 1, 1),
  (7, 1, 1),
  (8, 1, 1),
  (9, 1, 1),
  (10, 1, 1),
  (11, 1, 1),
  (12, 1, 1),
  (13, 5, 20),
  (14, 1, 35),
  (15, 8, 10),
  (16, 3, 40),
  (17, 3, 40),
  (18, 2, 1),
  (19, 2, 1),
  (20, 2, 1),
  (21, 2, 1),
  (22, 6, 1),
  (23, 4, 30),
  (24, 5, 20),
  (25, 6, 30),
  (26, 8, 20),
  (27, 7, 100),
  (28, 8, 20),
  (29, 1, 25),
  (30, 2, 1),
  (31, 2, 1),
  (32, 2, 1),
  (33, 7, 100),
  (34, 8, 30),
  (35, 2, 1),
  (36, 2, 1),
  (37, 4, 40),
  (38, 5, 25),
  (39, 6, 30),
  (40, 7, 1),
  (41, 7, 1),
  (42, 8, 35),
  (43, 8, 30),
  (44, 6, 1);

-- ------------------
-- Records of COURSES
-- ------------------
INSERT INTO courses (teacher_id, course_name, course_code, course_description, course_length)
VALUES
  (1, 'Introduction to Theater', 101, 'An introductory course covering the basics of theater and performance art.', 2),
  (2, 'Literary Analysis', 201, 'An in-depth exploration of literary theory and critical analysis.', 3),
  (5, 'Creative Writing Workshop', 301, 'A hands-on workshop focusing on various forms of creative writing.', 4),
  (4, 'History of Art', 105, 'A study of art history from ancient times to modern movements.', 2),
  (3, 'Film Studies', 106, 'An introduction to film analysis and the history of cinema.', 2),
  (6, 'World History', 102, 'A comprehensive survey of world history from ancient civilizations to modern times.', 2),
  (8, 'Introduction to Linguistics', 202, 'An overview of the scientific study of language and its structure.', 3),
  (10, 'Cultural Studies Seminar', 302, 'An examination of cultural phenomena and their impact on society.', 4),
  (9, 'Philosophy of Mind', 107, 'An exploration of philosophical questions related to consciousness and cognition.', 2),
  (7, 'Social Anthropology', 203, 'An introduction to the study of societies and human cultures.', 3),
  (11, 'Introduction to Computer Science', 103, 'Fundamental concepts and principles of computer science and programming.', 2),
  (13, 'Data Science Fundamentals', 203, 'An introduction to data analysis, machine learning, and statistical modeling.', 3),
  (15, 'Cybersecurity Essentials', 303, 'A hands-on course covering essential cybersecurity concepts and practices.', 4),
  (12, 'Algorithms and Data Structures', 108, 'An introductory course on algorithms and efficient data structures.', 3),
  (14, 'Software Engineering Principles', 204, 'Fundamentals of software design, architecture, and project management.', 3),
  (16, 'Calculus I', 104, 'An introductory course on differential and integral calculus.', 2),
  (18, 'Statistics for Decision Making', 204, 'A study of basic statistical methods for decision-making in various fields.', 3),
  (20, 'Mathematical Physics', 304, 'An advanced course integrating mathematical techniques with principles of physics.', 4),
  (17, 'Linear Algebra', 109, 'A course on vector spaces, linear transformations, and matrices.', 3),
  (19, 'Differential Equations', 205, 'An introduction to ordinary differential equations and their applications.', 3),
  (21, 'Introduction to Robotics', 110, 'Basics of robotics engineering including mechanics and control.', 3),
  (22, 'Digital Systems Design', 206, 'Principles of digital logic and circuit design.', 3),
  (23, 'Engineering Thermodynamics', 305, 'Fundamentals of thermodynamics for engineering applications.', 4),
  (24, 'Fluid Mechanics', 111, 'Introduction to fluid behavior and its applications in engineering.', 3),
  (25, 'Materials Science', 207, 'Study of the properties and applications of engineering materials.', 3),
  (26, 'Electrical Installation Basics', 112, 'A course on electrical systems, wiring, and safety standards.', 2),
  (27, 'Carpentry and Woodworking', 208, 'An introduction to woodworking techniques and tools.', 3),
  (28, 'Plumbing Essentials', 306, 'Core concepts in plumbing installation and maintenance.', 4),
  (29, 'Automotive Maintenance', 113, 'Basics of automotive repair and maintenance practices.', 3),
  (30, 'Welding Techniques', 209, 'Practical training in various welding techniques.', 3);

-- -----------------------------
-- Records of DEPARTMENT_COURSES
-- ------------------------------
INSERT INTO department_courses (dep_id, course_id)
VALUES
  (1, 101),
  (1, 201),
  (1, 301),
  (1, 105),
  (1, 106),
  (2, 102),
  (2, 202),
  (2, 302),
  (2, 107),
  (2, 203),
  (3, 103),
  (3, 203),
  (3, 303),
  (3, 108),
  (3, 204),
  (4, 104),
  (4, 204),
  (4, 304),
  (4, 109),
  (4, 205),
  (5, 110),
  (5, 206),
  (5, 305),
  (5, 111),
  (5, 207),
  (6, 112),
  (6, 208),
  (6, 306),
  (6, 113),
  (6, 209);

-- ------------------
-- Records of TEACHER
-- ------------------
INSERT INTO teachers (staff_id, room_id, teacher_role, teacher_tenure, phone_ext)
VALUES

-- ----------------------
-- Records of OFFICE_HOUR
-- ----------------------
INSERT INTO office_hour (start_time, end_time, date)
VALUES

-- ------------------------------
-- Records of TEACHER_OFFICE_HOUR
-- ------------------------------
INSERT INTO teacher_office_hour (teacher_id, hour_id)
VALUES

-- ------------------
-- Records of SESSION
-- ------------------
INSERT INTO session (module_id, room_id, session_type, session_start_time, ession_end_time, session_date, session_feedback, session_mandatory, session_description)
VALUES

-- --------------------------
-- Records of TEACHER_SESSION
-- --------------------------
INSERT INTO teacher_session (session_id, teacher_id)
VALUES

-- ---------------------
-- Records of ATTENDANCE
-- ---------------------
INSERT INTO attendance (session_id, student_id, addendance_record)
VALUES

-- -------------------------
-- Records of STUDENT_COURSE
-- -------------------------
INSERT INTO student_course (student_id, course_id, progress_perc, feedback, culmative_average, course_rep)
VALUES

-- -----------------
-- Records of MODULE
-- -----------------
INSERT INTO module (module_code, module_name, module_description, academ_lvl, module_credits, module_status, last_reviewed, notional_hours, module_duration)
VALUES
('TH10101', 'Theater History', 'An overview of the history of theater from ancient times to the present.', 'L4', 20, 'Active', '2024-06-15', 150.00, 12),
('TH10102', 'Acting Techniques', 'Exploration of various acting techniques and methods.', 'L5', 20, 'Active', '2024-06-15', 150.00, 12),
('TH10103', 'Stage Design Basics', 'Introduction to basic concepts in stage design and set decoration.', 'L6', 40, 'Active', '2024-06-15', 200.00, 18),
('LI20101', 'Introduction to Literary Theory', 'An introduction to different approaches to literary analysis.', 'L4', 20, 'Active', '2024-06-20', 150.00, 12),
('LI20102', 'Critical Reading Skills', 'Development of critical reading and analysis skills.', 'L5', 20, 'Active', '2024-06-20', 150.00, 12),
('LI20103', 'Literary Movements', 'Study of significant literary movements throughout history.', 'L6', 40, 'Active', '2024-06-20', 200.00, 18),
('CW30101', 'Fiction Writing', 'Workshop focusing on writing short stories and novels.', 'L4', 20, 'Active', '2024-06-25', 150.00, 12),
('CW30102', 'Poetry Workshop', 'Workshop focusing on writing poetry and verse.', 'L6', 20, 'Active', '2024-06-25', 150.00, 12),
('CW30103', 'Writing for Television', 'Workshop on writing scripts for television series.', 'L5', 40, 'Active', '2024-06-25', 200.00, 18),
('HI10201', 'Ancient Civilizations', 'Study of the rise and fall of ancient civilizations.', 'L4', 20, 'Active', '2024-06-10', 150.00, 12),
('HI10202', 'Modern History', 'Exploration of major events and developments in modern history.', 'L5', 20, 'Active', '2024-06-10', 150.00, 12),
('HI10203', 'World Wars in Context', 'Detailed study of the causes and impact of the World Wars.', 'L6', 40, 'Active', '2024-06-10', 200.00, 18),
('LN20201', 'Phonetics and Phonology', 'Study of speech sounds and their patterns.', 'L4', 20, 'Active', '2024-06-20', 150.00, 12),
('LN20202', 'Syntax and Semantics', 'Study of sentence structure and meaning in language.', 'L5', 20, 'Active', '2024-06-20', 150.00, 12),
('LN20203', 'Language Acquisition', 'An exploration of how people learn language.', 'L6', 40, 'Active', '2024-06-20', 200.00, 18),
('CS10301', 'Introduction to Programming', 'Fundamentals of programming using a high-level language.', 'L4', 20, 'Active', '2024-06-05', 150.00, 12),
('CS10302', 'Algorithms and Data Structures', 'Study of algorithms and data structures used in computer science.', 'L5', 20, 'Active', '2024-06-05', 150.00, 12),
('CS10303', 'Advanced Computing Concepts', 'In-depth study of advanced computing theories.', 'L6', 40, 'Active', '2024-06-05', 200.00, 18),
('DS20301', 'Statistical Analysis', 'Introduction to statistical methods for data analysis.', 'L5', 20, 'Active', '2024-06-10', 150.00, 12),
('DS20302', 'Machine Learning Basics', 'Fundamentals of machine learning algorithms and techniques.', 'L6', 40, 'Active', '2024-06-10', 200.00, 18),
('CY30301', 'Network Security', 'Study of principles and techniques for securing computer networks.', 'L5', 20, 'Active', '2024-06-08', 150.00, 12),
('CY30302', 'Ethical Hacking', 'Introduction to ethical hacking and penetration testing.', 'L7', 40, 'Active', '2024-06-08', 200.00, 18),
('MT10401', 'Differential Calculus', 'Study of rates of change and slopes of curves.', 'L5', 20, 'Active', '2024-06-12', 150.00, 12),
('MT10402', 'Integral Calculus', 'Study of accumulation and area under curves.', 'L6', 40, 'Active', '2024-06-12', 200.00, 18),
('ST20401', 'Descriptive Statistics', 'Presentation and analysis of data using graphical and numerical methods.', 'L6', 20, 'Active', '2024-06-15', 150.00, 12),
('ST20402', 'Inferential Statistics', 'Estimation and hypothesis testing using statistical methods.', 'L7', 40, 'Active', '2024-06-15', 200.00, 18),
('PH30401', 'Classical Mechanics', 'Study of the motion of objects and systems under the influence of forces.', 'L6', 20, 'Active', '2024-06-18', 150.00, 12),
('PH30402', 'Quantum Mechanics', 'Introduction to the principles of quantum mechanics.', 'L7', 40, 'Active', '2024-06-18', 200.00, 18);

-- -------------------------
-- Records of COURSE_MODULE
-- -------------------------
INSERT INTO course_module (course_id, module_id)
VALUES
(1, 1),
(1, 2),
(1, 3),
(2, 4),
(2, 5),
(2, 6),
(3, 7),
(3, 8),
(3, 9),
(4, 10),
(4, 11),
(4, 12),
(5, 13),
(5, 14),
(5, 15),
(6, 16),
(6, 17),
(6, 18),
(7, 19),
(7, 20),
(8, 21),
(8, 22),
(9, 23),
(9, 24),
(10, 25),
(10, 26),
(11, 27),
(11, 28);

-- -----------------------------
-- Records of COURSE_COORDINATOR
-- -----------------------------
INSERT INTO course_coordinator (teacher_id, course_id)
VALUES

-- -----------------------------
-- Records of MODULE_COORDINATOR
-- -----------------------------
INSERT INTO module_coordinator (teacher_id, module_id)
VALUES


-- --------------------------------
-- Records of STUDENT_MODULE_RESULT
-- --------------------------------
INSERT INTO student_module_result (student_id, module_id, module_grade, feedback, passed)
VALUES

-- ---------------------
-- Records of ASSESSMENT
-- ---------------------
INSERT INTO assessment (module_id, assessment_title, assessment_set_date, assessment_due_date, assessment_set_time, assessment_due_time, assessment_description, assessment_type, assessment_weighting, assessment_attachment, assessment_max_attempts, assessment_visble)
VALUES

-- -----------------------------
-- Records of ASSESSMENT_ATTEMPT
-- -----------------------------
INSERT INTO module_assessment_grade (assessment_id, student_id, assessment_grade)
VALUES
(1, 1, 85),
(2, 1, 72),
(3, 2, 90),
(4, 2, 65),
(5, 3, 78),
(6, 3, 80),
(7, 4, 70),
(8, 4, 88),
(9, 5, 95),
(10, 5, 84),
(11, 6, 75),
(12, 6, 60),
(13, 7, 85),
(14, 7, 72),
(15, 8, 90),
(16, 8, 65),
(17, 9, 78),
(18, 9, 80),
(19, 9, 70),
(20, 9, 88);

-- ----------------------------
-- Records of TEACHING_SESSION
-- ----------------------------
INSERT INTO teaching_session (module_id, session_type, session_start_time, session_length, session_date, session_notes)
VALUES
(1, 'Lecture', '09:00:00', 60.00, '2024-03-05', 'Introduction to Theater History'),
(2, 'Workshop', '13:00:00', 120.00, '2024-03-06', 'Acting Techniques Practical Session'),
(3, 'Seminar', '10:00:00', 120.00, '2024-03-07', 'Discussion on Literary Theory Approaches'),
(4, 'Tutorial', '11:00:00', 60.00, '2024-03-08', 'Critical Reading Skills Group Exercise'),
(5, 'Workshop', '14:00:00', 120.00, '2024-03-09', 'Fiction Writing Workshop Session'),
(6, 'Workshop', '13:00:00', 120.00, '2024-03-10', 'Poetry Workshop Analysis Session'),
(7, 'Lecture', '09:00:00', 60.00, '2024-03-11', 'Ancient Civilizations Overview'),
(8, 'Seminar', '10:00:00', 60.00, '2024-03-12', 'Modern History Discussion Forum'),
(9, 'Tutorial', '11:00:00', 60.00, '2024-03-13', 'Phonetics and Phonology Practice Exercises'),
(10, 'Seminar', '14:00:00', 60.00, '2024-03-14', 'Syntax and Semantics Case Studies'),
(11, 'Lecture', '09:00:00', 60.00, '2024-03-15', 'Introduction to Popular Culture'),
(12, 'Tutorial', '11:00:00', 120.00, '2024-03-16', 'Gender Studies Debate Session'),
(13, 'Lecture', '09:00:00', 60.00, '2024-03-17', 'Introduction to Programming Basics'),
(14, 'Seminar', '10:00:00', 60.00, '2024-03-18', 'Algorithms and Data Structures Review'),
(15, 'Workshop', '13:00:00', 120.00, '2024-03-19', 'Statistical Analysis Lab Session'),
(16, 'Workshop', '14:00:00', 120.00, '2024-03-20', 'Introduction to Machine Learning Workshop'),
(17, 'Seminar', '10:00:00', 60.00, '2024-03-21', 'Network Security Discussion'),
(18, 'Workshop', '13:00:00', 120.00, '2024-03-22', 'Ethical Hacking Practice Session'),
(19, 'Tutorial', '11:00:00', 120.00, '2024-03-23', 'Differential Calculus Problem Solving'),
(20, 'Seminar', '10:00:00', 120.00, '2024-03-24', 'Integral Calculus Discussion Forum');

-- ----------------------------
-- Records of TEACHER_SESSIONS
-- ----------------------------
INSERT INTO teachers_sessions (teacher_id, session_id)
VALUES
(1, 1),
(1, 2),
(2, 3),
(2, 4),
(5, 5),
(5, 6),
(6, 7),
(6, 8),
(8, 9),
(8, 10),
(10, 11),
(10, 12),
(11, 13),
(11, 14),
(13, 15),
(13, 16),
(15, 17),
(15, 18),
(16, 19),
(16, 20);

-- ----------------------------------
-- Records of ACADEMIC_HELP_SESSIONS
-- ----------------------------------
INSERT INTO academic_help_sessions (student_id, ah_session_type, ah_session_start_time, ah_session_length, ah_session_date, ah_session_notes)
VALUES
(1, 'One-on-One Tutoring', '14:00:00', 1.00, '2024-02-15', 'Tutoring session for exam preparation'),
(2, 'One-on-One Tutoring', '10:00:00', 1.50, '2024-02-17', 'Tutoring session for math assignment'),
(3, 'One-on-One Tutoring', '13:30:00', 2.00, '2024-02-18', 'Tutoring session for essay writing skills');

-- --------------------------------
-- Records of TEACHERS_AH_SESSIONS
-- --------------------------------
INSERT INTO teachers_ah_sessions (teacher_id, ah_session_id)
VALUES
(1, 1),
(2, 2),
(3, 3);

-- ----------------------
-- Records of ATTENDANCE
-- ----------------------
INSERT INTO attendance (student_id, session_id, attendance_record)
VALUES
(1, 1, TRUE),
(1, 2, TRUE),
(2, 3, TRUE),
(2, 4, FALSE),
(3, 5, TRUE),
(3, 6, TRUE),
(4, 7, TRUE),
(4, 8, TRUE),
(5, 9, TRUE),
(5, 10, FALSE),
(6, 11, TRUE),
(6, 12, TRUE),
(7, 13, TRUE),
(7, 14, TRUE),
(8, 15, TRUE),
(8, 16, TRUE),
(9, 17, TRUE),
(9, 18, TRUE),
(9, 19, FALSE),
(9, 20, TRUE);

-- ------------------
-- Records of SALARY
-- ------------------
INSERT INTO salary (salary_base, salary_bonuses, salary_start_date, salary_end_date) 
VALUES 
(50000.00, 5000.00, '2023-01-01', '2023-12-31'),
(60000.00, 6000.00, '2024-01-01', '2024-12-31'),
(55000.00, 5500.00, '2025-01-01', NULL);

-- ------------------------
-- Records of STAFF_SALARY
-- ------------------------
INSERT INTO staff_salary (salary_id, staff_id)
VALUES
(1, 1), 
(1, 2), 
(1, 3), 
(1, 4), 
(1, 5),
(1, 6), 
(1, 7), 
(1, 8),
(2, 9), 
(2, 10), 
(2, 11), 
(2, 12),
(2, 13), 
(2, 14), 
(2, 15), 
(2, 16),
(3, 17), 
(3, 18), 
(3, 19), 
(3, 20), 
(3, 21), 
(3, 22),
(3, 23),
(3, 24);

-- -----------------
-- Records of HOURS
-- -----------------
INSERT INTO hours (start_time, end_time, date)
VALUES
('09:00:00', '17:00:00', '2023-01-01'),
('08:00:00', '16:30:00', '2023-01-02'),
('10:00:00', '18:00:00', '2023-01-03');

-- -----------------------
-- Records of STAFF_HOURS
-- -----------------------
INSERT INTO staff_hours (hour_id, staff_id)
VALUES
(1, 1), 
(1, 2), 
(1, 3), 
(1, 4), 
(1, 5), 
(1, 6), 
(1, 7), 
(1, 8),
(2, 9), 
(2, 10), 
(2, 11), 
(2, 12), 
(2, 13), 
(2, 14), 
(2, 15), 
(2, 16),
(3, 17), 
(3, 18), 
(3, 19), 
(3, 20), 
(3, 21), 
(3, 22), 
(3, 23), 
(3, 24);

-- ---------------------
-- Records of DEDUCTION
-- ---------------------
INSERT INTO deduction (deduction_title, deduction_details, deduction_amount)
VALUES
('Tax', 'Income tax deduction for January', 1500.00),
('Health Insurance', 'Monthly health insurance premium', 200.00),
('Pension', 'Contribution to employee pension plan', 500.00);

-- -------------------------
-- Records of SALARY_PAYSLIP
-- -------------------------
INSERT INTO salary_payslip (salary_id, issue_date, start_date, end_date, net_pay, gross_pay, payment_method, tax_code, tax_period, national_insurance_num, hourly_rate)
VALUES
(1, '2023-01-31', '2023-01-01', '2023-01-31', 4500.00, 5000.00, 'Direct Deposit', '1250L', 1, 'AB123456C', 20.00),
(2, '2023-02-28', '2023-02-01', '2023-02-28', 5500.00, 6000.00, 'Cheque', '1200L', 2, 'CD987654A', 25.00),
(3, '2023-03-31', '2023-03-01', '2023-03-31', 5000.00, 5500.00, 'Bank Transfer', '1300L', 3, 'EF345678B', 22.00);

-- ----------------------------
-- Records of SALARY_DEDUCTION
-- ----------------------------
INSERT INTO salary_deduction (deduction_id, salary_id)
VALUES
(1, 1), 
(2, 1),
(1, 2), 
(3, 2),
(2, 3), 
(3, 3);