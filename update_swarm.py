import os

path = 'Flyntic-Studio-Demo-main/Godot/SwarmController.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

old_mesh = '''\t\t# Low-hardware friendly proxy mesh for followers
\t\tvar body = MeshInstance3D.new()
\t\tvar m = SphereMesh.new()
\t\tm.radius = 0.18
\t\tm.height = 0.36
\t\tm.radial_segments = 8
\t\tm.rings = 4
\t\tbody.mesh = m
\t\tvar mat = StandardMaterial3D.new()
\t\tmat.albedo_color = Color(0.2, 0.9, 0.9, 0.85)
\t\tmat.emission_enabled = true
\t\tmat.emission = Color(0.1, 0.6, 0.8)
\t\tmat.emission_energy_multiplier = 1.2
\t\tbody.material_override = mat
\t\tn.add_child(body)'''

new_mesh = '''\t\tvar body = MeshInstance3D.new()
\t\tvar mesh_res = load("res://Components/quad_pvc_frame.obj")
\t\tif mesh_res != null:
\t\t\tbody.mesh = mesh_res
\t\t\tbody.scale = Vector3(0.01, 0.01, 0.01) # scale to match Main drone
\t\telse:
\t\t\tvar m = SphereMesh.new()
\t\t\tm.radius = 0.18
\t\t\tm.height = 0.36
\t\t\tbody.mesh = m
\t\t
\t\tvar mat = StandardMaterial3D.new()
\t\tmat.albedo_color = Color(0.2, 0.9, 0.9, 0.85)
\t\tmat.emission_enabled = true
\t\tmat.emission = Color(0.1, 0.6, 0.8)
\t\tmat.emission_energy_multiplier = 1.2
\t\tbody.material_override = mat
\t\tn.add_child(body)'''

text = text.replace(old_mesh, new_mesh)
text = text.replace('var _formation_radius := 4.0', 'var _formation_radius := 9.0')
text = text.replace('var _separation_radius := 1.5', 'var _separation_radius := 4.5')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("Updated SwarmController")
