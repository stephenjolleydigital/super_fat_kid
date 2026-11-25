# Level 1_6 world exit

The finish flag at (688, -40) becomes available after GnomeBoss finishes its
death sequence and leaves the scene. Touching it takes control of Fatkid,
stops background music, and shows “World 2 Cleared” with a center-screen slam
and animated rays. After the jingle/celebration, Fatkid walks right to the
manhole at (776, -8), drops through it, and transitions to World2Entry.

On the Level_1_6_Boss root, assign **World Clear Jingle** when the audio is
ready. Until then it uses the existing level-complete jingle. The celebration
waits at least Celebration Seconds and allows the jingle to finish.

**Cutscene Path** currently points to `res://scenes/levels/World2Entry.tscn`,
a half-second black placeholder that continues to Level_2_1. Replace its
contents with the future cutscene and call `finish_cutscene()` at its end
(remove the placeholder's automatic continuation). Alternatively assign a
new scene and have it call `SceneTransition.change_scene(destination)`;
the destination is available as
`SceneTransition.get_meta(&"world_exit_destination")`.

**Next Level Path** controls the final destination. If Cutscene Path is empty
or missing, the exit goes directly there. The manhole uses temporary drawn
pixel art and can be replaced later. Other levels retain their usual banner
and completion flow. Session upgrades and lives carry through the transition.

Validation: Godot 4.4.1 headless editor parse/import passed. A runtime smoke
test verified the boss gate, player contact activation, automatic walk/fall,
placeholder handoff, arrival in Level_2_1, and preservation of lives.
