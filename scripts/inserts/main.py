combined = "/* SHARED INSERTS */"

with open('../../inserts/shared.sql', 'r') as file:
  combined +=  "\n\n" + file.read()

with open('../../inserts/b01.sql', 'r') as file:
  combined += "\n\n/* BRANCH b01 INSERTS */"
  combined +=  "\n\n" + file.read()

with open('../../inserts/b02.sql', 'r') as file:
  combined += "\n\n/* BRANCH b02 INSERTS */"
  combined +=  "\n\n" + file.read()

with open('../../inserts/inserts.sql', 'w') as file:
  file.write(combined)

oneline = ""

split_inserts = combined.split("INSERT INTO")

for group in split_inserts:
  group = group.strip()
  table = group.split(" ")[0]

  lines = group.split("\n")

  if len(lines) > 4:
    inserts = lines.pop(0)
    lines.pop(0)
    lines.pop()
    lines.pop()

    oneline += f"\n-- Records of {table}"

    for line in lines:
      line = line.strip()

      if line and line[0] == "(":
        line = line.rstrip(",")
        line = line.rstrip(";")

        oneline += f"\nINSERT INTO {inserts} VALUES {line};"

    oneline += "\n"

with open('../../inserts/oneline_inserts.sql', 'w') as file:
  file.write(oneline)