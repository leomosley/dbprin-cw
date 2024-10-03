# Group 26's DSD CW1 Database Implementation
This is our groups physical implementation of the relational database for Stellar Education Solutions. It consists of all entities outlined in the ERD 

([View PDF here](https://drive.google.com/file/d/1nB0oTYydLEmE2_XtO4u9A2eawc3cBWs-/view?usp=drive_link)) 
along with inserts of mock data to test/prove functionalty of the database.

## Installation
First create and connect to the database using your psql shell. Replace `YOUR_DATABASE` with whatever you wish to name the database.

```sql
CREATE DATABASE YOUR_DATABASE;
```

```
\c YOUR_DATABASE;
```

Then copy and paste the contents of [Group26_CW1.sql](/Group26_CW1.sql) into the psql shell. This will create all functions, triggers, indexes, tables, views, 
and all inserts - you wish to create the database without inserts copy and paste the contents of the [schema.sql](/schema.sql) instead.

## Usage
When inserting into certain tables make sure not to include columns which are generated by a default value or trigger. Instead use the insert format shown below:

## Using Views

### View 1

**Description:** 

**Usage:** 
```sql
SELECT * FROM VIEW;
```

**Columns:**
- Column