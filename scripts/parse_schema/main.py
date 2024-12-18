with open('../../schemas/branch_template.sql', 'r') as file:
  content = file.read()

updated_content = content.replace('%', r'%%')
updated_content = updated_content.replace('branch_template', '%I')
updated_content = updated_content.replace("'", "''")
updated_content = updated_content.replace("$$", "$inner$")
updated_content = "\n".join(
  line for line in updated_content.splitlines() if not (line.strip().startswith("--") or line.strip().startswith("/*"))
)

sections = [section.strip() for section in updated_content.split("\n\n") if section.strip()]

wrapped_sections = []

for section in sections:
  schema_names = ", ".join(["schema_name"] * section.count('%I'))  # Prepare schema name placeholders
  section_name = "".join(char for char in section.split("\n")[0] if char == char.lower() and char != " ")
  formatted_section = f"RAISE NOTICE 'CREATING %', '{section_name}';\nEXECUTE format('\n{section}'\n, {schema_names});"
  indented_section = "\n".join(f"\t{line}" for line in formatted_section.splitlines())  # Add one tab per line
  wrapped_sections.append(indented_section)

final_content = "\n\n".join(wrapped_sections)

wrapped_function = f"""CREATE OR REPLACE FUNCTION shared.create_schema(schema_name TEXT)
RETURNS void AS $$
BEGIN
  RAISE NOTICE 'CREATING SCHEMA %', schema_name;

{final_content}
END; 
$$ LANGUAGE plpgsql;"""

with open('output.sql', 'w') as file:
  file.write(wrapped_function)