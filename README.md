# Group 26 DBPRIN CW1
This is the implementation of the RDS for SES. The file [`Group26_CW1.sql`](Group26_CW1.sql) contains all the combined code (views, functions, inserts, tables, queries, etc). This is the file you should create the database using. We recommend using the PSQL CLI to create the database as it is much more efficient (see command below). 

First create the database in the PSQL CLI using:
```sql
CREATE DATABASE <database_name>;
```

Then you can execute the SQL code directly from the file using:
```bash
 psql -d <database_name> -f Group26_CW1.sql
```

The rest of the codebase is partitioned up as much as possilble to make it easier to view what each part of the code it self does. The [`schemas`](schemas) directory contains the code for the shared schema and the template schema for each tenant [(`branch_template.sql')](schemas/branch_template.sql). 

The [`inserts`](inserts) directory contains the inserts for each branch, the old inserts from a previous iteration, the combined [inserts](inserts/inserts.sql), and the inserts converted into individual oneline statements to prevent bugs in the database creation process. 

The [`queries.sql`](queries.sql) file contains all the 5 businesses related queries that are required by the specfication, each labeled with a comment to show which query in the document they relate to. The [`views.sql`](views.sql) contains all the views in both the shared and branch specific schemas. Similalry the [`functions.sql`](functions.sql) file contains all the functions in both the shared and branch specfic schemas.

The [`scripts`](scripts) directory contains all the scripts used to aid in the development of the code for the database. The [`parse_schema`](scripts/parse_schema/main.py) script takes the contents of the template branch schema and parses it to produce the function which dynamically creates the schema. The [`gen_sql`](scripts/gen_sql/main.py) script helps to generate specific inserts programtically for things like sessions and assessments to reduce repetitive tasks. Finally, the [`insserts`](scripts/inserts/main.py) combines each branches inserts into one file and then generates the single line inserts statements from that. 
