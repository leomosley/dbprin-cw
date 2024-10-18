/*
  Group 26 DBPRIN Coursework Database Schema
  ERD PDF: https://drive.google.com/file/d/1nB0oTYydLEmE2_XtO4u9A2eawc3cBWs-/view?usp=drive_link
  Github Repo: https://github.com/leomosley/dbprin-cw
*/

CREATE TABLE
    branch (
        branch_id serial PRIMARY KEY NOT NULL,
        branch_name VARCHAR(50) NOT NULL,
        branch_status ENUM NOT NULL,
        branch_addr1 VARCHAR(150),
        branch_addr2 VARCHAR(150),
        branch_postcode VARCHAR(10),
        branch_contact_number VARCHAR(15)
        branch_email VARCHAR(150) NOT NULL
    );
CREATE TABLE
    department (
        dep_id serial PRIMARY KEY NOT NULL,
        dep_name VARCHAR(50) NOT NULL,
        dep_type ENUM,
        dep_description VARCHAR(200)
    );
CREATE TABLE
    branch_department (
        branch_id INT NOT NULL,
        dep_id INT NOT NULL,
        PRIMARY KEY (branch_id, dep_id),
        CONSTRAINT fk_branch FOREIGN KEY (branch_id) REFERENCES branch (branch_id),
        CONSTRAINT fk_department FOREIGN KEY (dep_id) REFERENCES department (dep_id)
    );
CREATE TABLE
    role (
        role_id serial PRIMARY KEY NOT NULL,
        role_name VARCHAR(50) NOT NULL
    );

CREATE TABLE staff(
    staff_id SERIAL PRIMARY KEY,
    staff_company_email CHAR(22),
    staff_number CHAR(10) NOT NULL,
    staff_fname VARCHAR(50) NOT NULL
    staff_mname 
    staff_lname
    UNIQUE (staff_company_email, staff_number)
);


  CREATE TABLE
    branch (
        language_id serial PRIMARY KEY NOT NULL,
        language_name VARCHAR(50) NOT NULL
    );CREATE TABLE
    branch (
        language_id serial PRIMARY KEY NOT NULL,
        language_name VARCHAR(50) NOT NULL
    );CREATE TABLE
    branch (
        language_id serial PRIMARY KEY NOT NULL,
        language_name VARCHAR(50) NOT NULL
    );

CREATE TABLE
    language (
        language_id serial PRIMARY KEY NOT NULL,
        language_name VARCHAR(50) NOT NULL
    );

INSERT INTO
    language (language_name)
VALUES
    ('English'),
    ('Finnish'),
    ('French'),
    ('Spanish');

CREATE TABLE
    film (
        film_id serial PRIMARY KEY NOT NULL,
        language_id INT NOT NULL,
        original_language_id INT NOT NULL,
        FOREIGN KEY (language_id) REFERENCES language (language_id),
        FOREIGN KEY (original_language_id) REFERENCES language (language_id),
        film_name VARCHAR(50) NOT NULL,
        release_year INT NOT NULL
    );

INSERT INTO
    film (
        language_id,
        original_language_id,
        film_name,
        release_year
    )
VALUES
    (1, 1, 'No Time to Die', 2021),
    (2, 1, 'The Joker', 2019),
    (3, 1, 'Inception', 2010),
    (4, 1, 'Titanic', 1997);

CREATE TABLE
    actor (
        actor_id serial PRIMARY KEY NOT NULL,
        actor_name VARCHAR(50) NOT NULL
    );

INSERT INTO
    actor (actor_name)
VALUES
    ('Daniel Craig'),
    ('Joaquin Phoenix'),
    ('Ben Whishaw'),
    ('Leonardo DiCaprio');

CREATE TABLE
    film_actor (
        film_id INT NOT NULL,
        actor_id INT NOT NULL,
        PRIMARY KEY (film_id, actor_id),
        CONSTRAINT fk_film FOREIGN KEY (film_id) REFERENCES film (film_id),
        CONSTRAINT fk_actor FOREIGN KEY (actor_id) REFERENCES actor (actor_id)
    );

INSERT INTO
    film_actor (film_id, actor_id)
VALUES
    (1, 1),
    (1, 3),
    (2, 2),
    (3, 4),
    (4, 4);

CREATE TABLE
    category (
        category_id serial PRIMARY KEY NOT NULL,
        category_name VARCHAR(50) NOT NULL
    );

INSERT INTO
    category (category_name)
VALUES
    ('action'),
    ('adventure'),
    ('thriller'),
    ('drama'),
    ('sci-fi'),
    ('romance'),
    ('history');

CREATE TABLE
    film_category (
        film_id INT NOT NULL,
        category_id INT NOT NULL,
        PRIMARY KEY (film_id, category_id),
        CONSTRAINT fk_film FOREIGN KEY (film_id) REFERENCES film (film_id),
        CONSTRAINT fk_category FOREIGN KEY (category_id) REFERENCES category (category_id)
    );

INSERT INTO
    film_category (film_id, category_id)
VALUES
    (1, 1),
    (1, 2),
    (1, 3),
    (2, 3),
    (2, 4),
    (3, 5),
    (3, 1),
    (3, 2),
    (3, 3),
    (4, 6),
    (4, 7),
    (4, 4);
