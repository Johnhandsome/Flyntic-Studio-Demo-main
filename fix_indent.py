import sys

path = 'Flyntic-Studio-Demo-main/Godot/Main.gd'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if '_mission_active = false' in line and lines[i-1].strip() == '_mission_planner.stop()':
        lines[i] = '\t\t_mission_active = false\n'
        break

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Fixed indentation')
