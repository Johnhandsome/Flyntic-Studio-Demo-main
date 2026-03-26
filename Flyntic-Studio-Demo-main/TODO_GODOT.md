# TODO for Godot Folder

> **For contributors: Please address the following issues in the Godot (FlynticStudio/Godot) folder only.**

## 1. Block Component Movement During Play
- When simulation is running (Play mode), all component manipulations (move, add, remove, wiring, etc.) must be blocked.
- Only camera/orbit controls should be allowed.

## 2. Improve Code Block UI (Scratch-like)
- Make code blocks visually smoother and more appealing.
- Each block should be visually wrapped/bordered like in Scratch (rounded corners, clear separation).
- Dragging and snapping blocks should feel smooth and intuitive.

## 3. Support Multiple Code Blocks (Sequences)
- Allow code blocks to be chained together (more than 2 blocks in a sequence).
- The drone should execute all connected commands in order, not just the first two.
- Ensure the workspace can handle and run long command chains.

## 4. Add Wiring Screen with Error Feedback
- Implement a dedicated wiring mode/screen for connecting component ports.
- User can manually connect wires between ports.
- If a user attempts an invalid connection, show a clear error/warning (e.g. exclamation mark, popup, or message).
- UI should allow zooming and easy navigation while wiring.

---
**Note:**
- Only apply these changes to the Godot folder (not web or other parts).
- Keep UI/UX consistent and user-friendly.
- If you have questions, please comment in the PR.
