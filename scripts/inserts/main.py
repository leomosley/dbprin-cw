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