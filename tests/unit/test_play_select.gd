extends GutTest

var play_select_scene = preload("res://Stages/UI/play_select/play_select.tscn")
var play_select: UI_PlaySelect

func before_each():
  play_select = play_select_scene.instantiate()
  add_child_autofree(play_select)
  await wait_process_frames(2)

func test_campaign_is_initial_selection_and_focus_owner():
  var campaign_card = play_select.get_node("SafeArea/Center/Page/Cards/CampaignCard")

  assert_eq(play_select.get_selected_mode(), &"campaign")
  assert_true(campaign_card.selected)
  assert_true(campaign_card.has_focus())
  assert_eq(campaign_card.focus_mode, Control.FOCUS_ALL)
  assert_false(campaign_card.disabled)
  assert_false(campaign_card.has_node("SelectedFrame"))
  assert_true(campaign_card.get_node("CardFill").visible)
  assert_eq(campaign_card.get_node("CardFill").color, Color(0.075, 0.082, 0.068, 1))
  assert_eq(campaign_card.get_node("CardFill").offset_left, 8.0)
  assert_eq(campaign_card.get_node("CardFill").offset_top, 8.0)
  assert_eq(campaign_card.get_node("CardFill").offset_right, -8.0)
  assert_eq(campaign_card.get_node("CardFill").offset_bottom, -8.0)
  assert_eq(campaign_card.get_node("Surface").texture.resource_path, "res://Assets/Textures/UI/canvas-panel.png")
  assert_false(campaign_card.get_node("Surface").visible)
  assert_true(campaign_card.get_node("FocusFrame").visible)
  assert_eq(campaign_card.get_node("FocusFrame").texture.resource_path, "res://Assets/Textures/UI/cyan-frame-small.png")
  assert_false(campaign_card.get_node("FocusFrame").draw_center)
  assert_eq(campaign_card.get_node("FocusFrame").patch_margin_left, 18)
  assert_eq(campaign_card.get_node("FocusFrame").patch_margin_top, 18)
  assert_eq(campaign_card.get_node("FocusFrame").patch_margin_right, 18)
  assert_eq(campaign_card.get_node("FocusFrame").patch_margin_bottom, 18)

func test_unselected_mode_cards_use_normal_frame_without_focus_frame():
  assert_true(_card(&"ChallengeCard").get_node("Surface").visible)
  assert_eq(_card(&"ChallengeCard").get_node("Surface").texture.resource_path, "res://Assets/Textures/UI/canvas-panel.png")
  assert_true(_card(&"ChallengeCard").get_node("Surface").draw_center)
  assert_false(_card(&"ChallengeCard").get_node("FocusFrame").visible)
  assert_true(_card(&"EndlessCard").get_node("Surface").visible)
  assert_eq(_card(&"EndlessCard").get_node("Surface").texture.resource_path, "res://Assets/Textures/UI/canvas-panel.png")
  assert_true(_card(&"EndlessCard").get_node("Surface").draw_center)
  assert_false(_card(&"EndlessCard").get_node("FocusFrame").visible)

func test_unavailable_modes_are_not_locked_and_skip_focus():
  var challenge_card = play_select.get_node("SafeArea/Center/Page/Cards/ChallengeCard")
  var endless_card = play_select.get_node("SafeArea/Center/Page/Cards/EndlessCard")

  for card in [challenge_card, endless_card]:
    assert_true(card.temporarily_disabled)
    assert_true(card.disabled)
    assert_eq(card.focus_mode, Control.FOCUS_NONE)
    assert_eq(card.get_node("InfoPanel/InfoMargin/Info/Status").text, "UNAVAILABLE")

func test_mode_cards_use_dedicated_horizontal_artwork_to_text_split():
  for card in _mode_cards():
    var art_clip: Control = card.get_node("ArtClip")
    var info_panel: Control = card.get_node("InfoPanel")

    assert_eq(art_clip.offset_left, 8.0)
    assert_lt(art_clip.anchor_right, info_panel.anchor_right)
    assert_eq(art_clip.anchor_right, info_panel.anchor_left)
    assert_eq(card.size_flags_vertical, Control.SIZE_EXPAND_FILL)
    assert_gte(card.custom_minimum_size.y, 166.0)

func test_mode_artwork_paths_are_configured():
  assert_eq(_card(&"CampaignCard").artwork.resource_path, "res://Assets/Textures/UI/mode-campaign.png")
  assert_eq(_card(&"ChallengeCard").artwork.resource_path, "res://Assets/Textures/UI/mode-challenge.png")
  assert_eq(_card(&"EndlessCard").artwork.resource_path, "res://Assets/Textures/UI/mode-endless.png")

func test_mode_artwork_source_region_can_be_shifted_per_card():
  var challenge_card = _card(&"ChallengeCard")
  var artwork_rect: TextureRect = challenge_card.get_node("ArtClip/Artwork")

  assert_eq(challenge_card.artwork_source_region, Rect2())
  assert_eq(artwork_rect.texture, challenge_card.artwork)
  assert_eq(artwork_rect.offset_left, 0.0)
  assert_eq(artwork_rect.offset_top, 0.0)
  assert_eq(artwork_rect.offset_right, 0.0)
  assert_eq(artwork_rect.offset_bottom, 0.0)

  challenge_card.artwork_source_region = Rect2(14, 9, 0, 0)

  assert_true(artwork_rect.texture is AtlasTexture)
  assert_eq(artwork_rect.texture.atlas, challenge_card.artwork)
  assert_eq(artwork_rect.texture.region, Rect2(Vector2(14, 9), challenge_card.artwork.get_size()))

  challenge_card.artwork_source_region = Rect2(14, 9, 520, 180)

  assert_eq(artwork_rect.texture.region, Rect2(14, 9, 520, 180))

func test_mouse_hover_does_not_change_focus_or_selection():
  var campaign_card = _card(&"CampaignCard")
  var challenge_card = _card(&"ChallengeCard")
  campaign_card.grab_focus()
  await wait_process_frames(1)

  challenge_card.emit_signal("mouse_entered")
  await wait_process_frames(1)

  assert_eq(play_select.get_selected_mode(), &"campaign")
  assert_true(campaign_card.selected)
  assert_false(challenge_card.selected)
  assert_true(campaign_card.has_focus())

func test_disabled_card_press_does_not_change_selection():
  var challenge_card = _card(&"ChallengeCard")

  challenge_card.emit_signal("pressed")

  assert_eq(play_select.get_selected_mode(), &"campaign")
  assert_false(challenge_card.selected)

func test_campaign_card_press_activates_campaign_mode():
  watch_signals(play_select)

  _card(&"CampaignCard").emit_signal("pressed")

  assert_signal_emitted_with_parameters(play_select, "mode_activated", [&"campaign"])

func test_accept_with_back_button_focus_does_not_activate_campaign():
  var back_button: TextureButton = play_select.get_node("SafeArea/Center/Page/Header/HeaderActions/BackButton")
  watch_signals(play_select)
  back_button.grab_focus()
  await wait_process_frames(1)

  play_select._unhandled_input(_input_action(&"ui_accept"))

  assert_signal_not_emitted(play_select, "mode_activated")

func test_back_button_sits_under_play_title_and_no_bottom_action_row():
  var back_button: TextureButton = play_select.get_node("SafeArea/Center/Page/Header/HeaderActions/BackButton")
  assert_not_null(back_button)
  assert_eq(back_button.texture_normal.resource_path, "res://Assets/Textures/UI/back-to-main-menu-button.png")
  assert_eq(back_button.custom_minimum_size, Vector2(300, 38))
  assert_false(play_select.has_node("SafeArea/Center/Page/Actions"))

func test_play_title_uses_banner_art():
  var play_banner: TextureRect = play_select.get_node("SafeArea/Center/Page/Header/PlayBanner")
  assert_eq(play_banner.texture.resource_path, "res://Assets/Textures/UI/play-banner.png")

func test_screen_uses_main_menu_background_art():
  var background: TextureRect = play_select.get_node("Background")
  assert_eq(background.texture.resource_path, "res://Assets/Textures/UI/main-menu-background.png")
  assert_eq(background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)

func test_screen_does_not_show_choose_mode_subtitle():
  assert_false(play_select.has_node("SafeArea/Center/Page/Header/SubtitleLabel"))

func test_mode_titles_do_not_show_numbers():
  for card in _mode_cards():
    assert_false(card.has_node("InfoPanel/InfoMargin/Info/TitleRow/Number"))

  for card in _mode_cards():
    for child in _all_control_descendants(card):
      assert_false(child is Button)

func _card(card_name: StringName):
  return play_select.get_node("SafeArea/Center/Page/Cards/%s" % card_name)

func _mode_cards() -> Array:
  return [
    _card(&"CampaignCard"),
    _card(&"ChallengeCard"),
    _card(&"EndlessCard"),
  ]

func _input_action(action: StringName) -> InputEventAction:
  var event := InputEventAction.new()
  event.action = action
  event.pressed = true
  return event

func _all_control_descendants(node: Node) -> Array[Control]:
  var controls: Array[Control] = []
  for child in node.get_children():
    if child is Control:
      controls.append(child)
    controls.append_array(_all_control_descendants(child))
  return controls
