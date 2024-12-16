import random
from datetime import datetime, timedelta

def save(output: str, name: str):
  timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
  with open(f"output/{name}_{timestamp}.sql", "w") as file:
    file.write(output)

def generate_assigment(modules: int):
  output = "INSERT INTO shared.assessment (module_id, assessment_title, assessment_description, assessment_type, assessment_weighting, assessment_attachment, assessment_visible)\nVALUES"
  for id in range(1, modules+1):
    weights = ['10.00', '30.00', '10.00', '50.00']
    random.shuffle(weights)
    
    if id <= 9:
      module_id = f"m00000{id}"
    else:
      module_id = f"m0000{id}"

    output += f"""
    ('{module_id}', 'General Exam', NULL, 'Exam', 0.00, NULL, TRUE),
    ('{module_id}', 'Final Exam',  NULL, 'Exam', {weights[0]}, NULL, TRUE),
    ('{module_id}', 'Coursework Project',  NULL, 'Coursework', {weights[1]}, NULL, TRUE),
    ('{module_id}', 'Essay', NULL, 'Essay', {weights[2]}, NULL, TRUE),
    ('{module_id}', 'Research Essay', NULL, 'Essay', 0.00, NULL, TRUE),
    ('{module_id}', 'Presentation', NULL, 'Presentation', {weights[3]}, NULL, TRUE),"""
  
  return output.rstrip(",") + ";"

def generate_session(modules: list[str], branch_id: str):
  base_date = datetime(2024, 11, 1)
  ignored_dates = [datetime(2024, 12, 22), datetime(2025, 1, 5)]
  output = f"INSERT INTO branch_{branch_id}.session (room_id, module_id, session_type, session_start_time, session_end_time, session_date, session_feedback, session_mandatory, session_description)\nVALUES"
  
  start_time_1 = 9
  end_time_1 = start_time_1 + 1
  start_time_2 = end_time_1
  end_time_2 = start_time_2 + 1
  weekday = 1

  for module_id in modules:
    session_details = [
      ('Lecture', f"{start_time_1}:00", f"{end_time_1}:00"),
      ('Practical', f"{start_time_2}:00", f"{end_time_2}:00"),
    ]
      
    for week in range(12):
      for (session_type, start_time, end_time) in session_details:
        session_date = base_date + timedelta(weeks=week)
        while session_date.weekday() != weekday or session_date in ignored_dates:
          session_date += timedelta(days=1)
              
        if session_type == 'Lecture':
          room_id = 1
        else:
          room_id = 2 if random.random() > 0.5 else 3

        formatted_date = session_date.strftime('%Y-%m-%d')
              
        output += f"\n\t({room_id}, '{module_id}', '{session_type}', '{start_time}', '{end_time}', '{formatted_date}', '', TRUE, ''),"
      
    start_time_1 += 1
    end_time_1 += 1
    start_time_2 += 1
    end_time_2 += 1

    if end_time_2 > 18:
      start_time_1 = 9
      end_time_1 = 10
      start_time_2 = 10
      end_time_2 = 11
      weekday += 1
      if weekday > 5:  
        weekday = 0

  return output.rstrip(",") + ";"

def link_staff_session(branch_id: str):
  staff_ids = [
    ['s000000001', 's000000002'],
    ['s000000002', 's000000003']
  ]

  splitter = ['m000001','m000002','m000003','m000004']

  output = f"INSERT INTO branch_{branch_id}.staff_session (staff_id, session_id)\nVALUES"
  with open("input/sessions.txt", "r") as text:
    for n, line in enumerate(text.readlines(), start=1):
      module_id = line.rstrip("\n")

      if module_id in splitter:
        ids = staff_ids[0]
      else:
        ids = staff_ids[1]

      for staff_id in ids:
        output += f"\n\t('{staff_id}', 'sesh{str(n).zfill(6)}'),"

  return output.rstrip(",") + ";"

def new_branch_inserts():
  staff_ids = {
    's000000001' : 's000000008', 
    's000000002' : 's000000009',  
    's000000003' : 's000000010',  
    's000000004' : 's000000011',  
    's000000005' : 's000000012',  
    's000000006' : 's000000013',  
    's000000007' : 's000000014'  
  }

  student_ids = {
    'sn00000001' : 'sn00000007', 
    'sn00000002' : 'sn00000008', 
    'sn00000003' : 'sn00000009', 
    'sn00000004' : 'sn00000010', 
    'sn00000005' : 'sn00000011', 
    'sn00000006' : 'sn00000012',
  }

  department_ids = {
    'd000001' : 'd000004',
    'd000003' : 'd000005'
  }

  course_ids = {
   'c000001' : 'c000007',
   'c000002' : 'c000008',
   'c000005' : 'c000009',
   'c000006' : 'c000010'
  }
  
  module_ids = {
    'm000001' : 'm000013',
    'm000002' : 'm000014',
    'm000003' : 'm000015',
    'm000004' : 'm000016',
    'm000009' : 'm000017',
    'm000010' : 'm000018',
    'm000011' : 'm000019',
    'm000012' : 'm000020'
  }

  with open("input/inserts.sql") as inserts:

    content = inserts.read()

    content = content.replace("b01", "b02")
    
    for staff_id in staff_ids:
      content = content.replace(staff_id, staff_ids[staff_id])

    for student_id in student_ids:
      content = content.replace(student_id, student_ids[student_id])
    
    for department_id in department_ids:
      content = content.replace(department_id, department_ids[department_id])
    
    for course_id in course_ids:
      content = content.replace(course_id, course_ids[course_id])
    
    for module_id in module_ids:
      content = content.replace(module_id, module_ids[module_id])
    
    for i in range(1, 194):
      sesh_id = "sesh"+str(i).zfill(6)
      new_id = "sesh"+str(i+193).zfill(6)

      content = content.replace(sesh_id, new_id)
    
    return content

if __name__ == "__main__":
  # save(generate_session(['m000001','m000002','m000003','m000004','m000009','m000010','m000011','m000012'], "b01"), "session")
  # save(link_staff_session("b01"), "staff_session")
  save(new_branch_inserts(), "b02_inserts")