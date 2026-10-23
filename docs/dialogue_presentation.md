# Dialogue presentations

`Style` remains the default bottom textbox for conversations. `Tutorial` is a
Dialogic style variation that stacks the same speaker portrait, text, and
Continue button in a right-hand panel. Both use the existing character portraits,
including `bot_sprite.png`; no new portrait assets are required.

Use Dialogic's built-in timeline events to select the presentation:

```text
[style name="Tutorial"]
survivor: Tutorial instructions here.
[style name="Style"]
survivor: Conversation here.
```

Keep the character's **Style** field unset when the timeline should choose the
presentation. A character style overrides the timeline's selection on every line.
The inherited style includes the base style's layer IDs because the bundled
Dialogic style-switching code uses that list to apply overrides to existing nodes.

Scenario 1 switches after accepting the tutorial and returns to the conversation
style before the closing encouragement. Its dialogue text, choices, pause/resume
calls, and wait events are unchanged. Wait events still hide the textbox until
the required gameplay signal arrives. Tutorial text and Continue accept mouse
input; clicks outside the panel do not advance it. Enter/Space retain Dialogic's
existing behavior, including its input delays and menu/Tech Tree pause handling.

## Verification

Run `./run_tests.sh -gselect=test_tutorial_presentation.gd` for the scenario-one
timeline, opt-in/opt-out, disabled tutorial, all gameplay waits, choice/Continue
input, menu blocking, style restoration, and panel bounds at 720p/1080p with
100%/200% UI scale.

For visual review, start Scenario 1 with the tutorial enabled, select **Yes**, and
check the portrait and long instruction text in the side panel. Attack a Zombie,
clear the first Wave, unlock the Scrap Shooter, and place it. Confirm the resource
display and Hotbar remain usable while each wait is active, and the closing lines
return to the bottom textbox. Repeat **No** and restart with tutorials disabled.
