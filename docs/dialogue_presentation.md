# Dialogue presentations

`BaseStyle` is the default bottom textbox for conversations. `Tutorial` is a
Dialogic style variation that stacks the speaker portrait, text, and Continue
button in a right-hand panel. The `system` character (displayed as **Tutorial**)
uses the question-mark portrait at [`Assets/Icons/question.png`](../Assets/Icons/question.png).
The layout does not change which portrait a character uses.

Use Dialogic's built-in timeline events to select the presentation:

```text
[style name="Tutorial"]
system: Tutorial instructions here.
[style name="BaseStyle"]
Survivor1: Conversation here.
```

Keep the character's **Style** field unset when the timeline should choose the
presentation. A character style overrides the timeline's selection on every line.
The inherited style includes the base style's layer IDs because the bundled
Dialogic style-switching code uses that list to apply overrides to existing nodes.

Car Defense switches to the side panel for the tutorial prompt and, if accepted,
returns to the bottom textbox before the closing encouragement. Wait events
hide the textbox until the required gameplay signal arrives. Tutorial text and
Continue accept mouse input; clicks outside the panel do not advance it.
Enter/Space retain Dialogic's input delays and menu/Tech Tree pause handling.

## Verification

Run `./run_tests.sh -gselect=test_tutorial_presentation.gd` for the scenario-one
timeline, opt-in/opt-out, disabled tutorial, all gameplay waits, choice/Continue
input, menu blocking, style restoration, and panel bounds at 720p/1080p with
100%/200% UI scale.

For visual review, start Car Defense with the tutorial enabled, select **Yes**, and
check the portrait and long instruction text in the side panel. Attack a Zombie,
clear the first Wave, unlock the Scrap Shooter, and place it. Confirm the resource
display and Hotbar remain usable while each wait is active, and the closing lines
return to the bottom textbox. Repeat **No** and restart with tutorials disabled.
