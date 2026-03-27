import os

path = 'Flyntic-Studio-Demo-main/Godot/SwarmController.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('var spacing = 1.6', 'var spacing = 4.5')
text = text.replace('float(i + 1) * 1.8)', 'float(i + 1) * 4.0)')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("Updated SwarmController constraints")
