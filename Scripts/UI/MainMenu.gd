extends Control

# --- MAIN MENU BUTTONS ---
@onready var button_start: Button = $CenterButtons/ButtonStart
@onready var button_shop: Button = $CenterButtons/ButtonShop
@onready var button_forge: Button = $CenterButtons/ButtonForge
@onready var button_quit: Button = $CenterButtons/ButtonQuit

# --- SUB-MENUS ---
@onready var shop_menu: Panel = $ShopMenu
@onready var forge_menu: Panel = $ForgeMenu
@onready var char_select_menu: Panel = $CharacterSelectMenu

# --- CLOSE BUTTONS ---
@onready var button_close_shop: Button = $ShopMenu/ButtonCloseShop
@onready var button_close_forge: Button = $ForgeMenu/ButtonCloseForge
@onready var button_close_char_select: Button = $CharacterSelectMenu/ButtonCloseCharSelect

# --- CHARACTER SELECT ELEMENTS ---
# Action Buttons
@onready var btn_customize: Button = $CharacterSelectMenu/ActionPanel/VBoxContainer/BtnCustomize
@onready var btn_mode: Button = $CharacterSelectMenu/ActionPanel/VBoxContainer/BtnMode
@onready var btn_challenge: Button = $CharacterSelectMenu/ActionPanel/VBoxContainer/BtnChallenge
@onready var btn_start_game: Button = $CharacterSelectMenu/ActionPanel/VBoxContainer/BtnStartGame

# Info Display References
@onready var name_label: Label = $CharacterSelectMenu/InfoPanel/VBoxContainer/NameLabel
@onready var desc_label: RichTextLabel = $CharacterSelectMenu/InfoPanel/VBoxContainer/DescLabel

# Character Buttons (References to the buttons in the grid)
@onready var btn_char_1: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar1
@onready var btn_char_2: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar2
@onready var btn_char_3: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar3 # Added if you made a 3rd one
@onready var btn_char_4: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar4 # Added if you made a 4th one
@onready var btn_char_5: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar5
@onready var btn_char_6: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar6
@onready var btn_char_7: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar7
@onready var btn_char_8: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar8
@onready var btn_char_9: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar9
@onready var btn_char_10: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar10
@onready var btn_char_11: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar11
@onready var btn_char_12: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar12
@onready var btn_char_13: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar13
@onready var btn_char_14: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar14
@onready var btn_char_15: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar15
@onready var btn_char_16: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar16
@onready var btn_char_17: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar17
@onready var btn_char_18: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar18
@onready var btn_char_19: Button = $CharacterSelectMenu/LeftContainer/CharGrid/BtnChar19

# Popups inside Character Select
@onready var customize_popup: Panel = $CharacterSelectMenu/CustomizePopup
@onready var mode_popup: Panel = $CharacterSelectMenu/ModePopup
@onready var challenge_popup: Panel = $CharacterSelectMenu/ChallengePopup

# Popup Close Buttons
@onready var btn_close_customize: Button = $CharacterSelectMenu/CustomizePopup/BtnCloseCustomize
@onready var btn_close_mode: Button = $CharacterSelectMenu/ModePopup/BtnCloseMode
@onready var btn_close_challenge: Button = $CharacterSelectMenu/ChallengePopup/BtnCloseChallenge

@onready var parameters_menu = $ParametersMenu
@onready var delete_confirm_dialog = $ParametersMenu/DeleteConfirmDialog # Ou $ParametersMenu/DeleteConfirmDialog selon où tu l'as mis

# --- DATA ---
var characters_data = {
	"char1": {
		"name": "TOR-OB1",
		"desc": "Robot humanoïde doté d'une tête de projecteur.\n\nArme: Projecteur\nPassif 1: Smoke Screen\nPassif 2: Magnet Module"
	},
	"char2": {
		"name": "Kat",
		"desc": "Humaine aux avant-bras robotisés.\n\nArme: Avant-bras à air comprimé\nPassif 1: Compressed Air Tanks\nPassif 2: Rapid Recoil"
	},
	"char3": {
		"name": "Zzokrugug",
		"desc": "Géant de roche élancé et fait de silex.\n\nArme: Lames silex\nPassif 1: Fraying\nPassif 2: Quake Impact"
	},
	"char4": {
		"name": "Irviktiti",
		"desc": "Statue de marbre de forme reptilienne animée.\n\nArme: Missiles purificateurs\nPassif 1: Manoeuvre d'Esquive\nPassif 2: Tir Armé"
	},
	"char5": {
		"name": "Krofhon",
		"desc": "Mage temporel à l'origine des malheurs du monde.\n\nArme: Sceptre de Déphasage\nPassif 1: oui\nPassif 2: oui"
	},
	"char6": {
		"name": "Shaqur",
		"desc": "Shaman polymorphe usant de ses haches pour proteger la foret."
	},
	"char7": {
		"name": "Khormol",
		"desc": "Demon a gueule beante, avide de chair fraiche."
	},
	"char8": {
		"name": "Perma",
		"desc": "Envoyee du Soleil et de la Lune, descendue pour retablir l'ordre et la justice."
	},
	"char9":{
		"name": "Vigo",
		"desc": "Humain dote d'une combinaison de nanobots dernier cri le protegeant."
	},
	"char10":{
		"name": "Fram",
		"desc": "Inferni enragee, elle n'a de cesse de chercher le combat pour son propre amusement."
	},
	"char11":{
		"name": "Naerum",
		"desc": "Creature de la foret informe a l'esprit vengeur."
	},
	"char12":{
		"name": "Sulphura",
		"desc": "Premiere des Inferni, sa malediction donna naissance a son peuple."
	},	
	"char13":{
		"name": "Sseroghol",
		"desc": "Demon des profondeurs commandant aux marees elles-memes."
	},
	"char14":{
		"name": "Hojo",
		"desc": "Creature au potentiel de destruction incroyable mais dont les convictions l'ont tournee vers la paix, et la peche."
	},
	"char15":{
		"name": "Guhulgghuru",
		"desc": "Leader des Durr Liberes, il est le premier a avoir brise ses chaines, jurant de ne plus jamais etre soumis a quiconque."
	},
	"char16":{
		"name": "Omocqitheqq",
		"desc": "Mausolee d'ames en peine, il etait autrefois utilise pour le Salut de ses maitres."
	},
	"char17":{
		"name": "Allucard",
		"desc": "Seigneur d'un peuple opprime par les Inferni, il a rallie sous sa banniere, et par l'aide de la deess de la Vie, son peuple."
	},
	"char18":{
		"name": "Liv, Ficu & Aduj",
		"desc": "Trio inseparable d'Infernis, sans grande ambition si ce n'est de jouer des tours aux autres, y compris les leurs."
	},
	"char19":{
		"name": "Gnarlhom",
		"desc": "Demon venu des cavernes profondes de la terre, incarnation meme de l'avidite des etres vivants."
	},
}

func _ready() -> void:
	# 1. Connect Main Menu
	button_quit.pressed.connect(_on_quit_pressed)
	button_shop.pressed.connect(_on_shop_pressed)
	button_forge.pressed.connect(_on_forge_pressed)
	button_start.pressed.connect(_on_open_char_select_pressed)
	
	# 2. Connect Close Main Sub-menus
	button_close_shop.pressed.connect(_on_close_main_sub_menus)
	button_close_forge.pressed.connect(_on_close_main_sub_menus)
	button_close_char_select.pressed.connect(_on_close_main_sub_menus)
	
	# 3. Connect Character Select Actions
	btn_customize.pressed.connect(func(): _open_popup(customize_popup, btn_close_customize))
	btn_mode.pressed.connect(func(): _open_popup(mode_popup, btn_close_mode))
	btn_challenge.pressed.connect(func(): _open_popup(challenge_popup, btn_close_challenge))
	btn_start_game.pressed.connect(_on_start_game_pressed)
	
	# 4. Connect Popup Close Buttons
	btn_close_customize.pressed.connect(_close_all_popups)
	btn_close_mode.pressed.connect(_close_all_popups)
	btn_close_challenge.pressed.connect(_close_all_popups)
	
	# Connexion pour ouvrir les paramètres (depuis le bouton "Param" en haut à droite)
	# Si ton bouton s'appelle "ButtonParameters" dans la scène :
	if has_node("TopRightButtons/ButtonParameters"):
		$TopRightButtons/ButtonParameters.pressed.connect(_on_button_parameters_pressed)
		
	# Connexion pour fermer les paramètres
	if parameters_menu.has_node("ButtonCloseParams"):
		parameters_menu.get_node("ButtonCloseParams").pressed.connect(_on_close_params_pressed)

	# Connexion du bouton "Effacer la sauvegarde"
	if parameters_menu.has_node("ButtonResetSave"):
		parameters_menu.get_node("ButtonResetSave").pressed.connect(_on_reset_save_pressed)
		
	# Connexion de la validation finale (le "Oui" de la fenêtre de dialogue)
	delete_confirm_dialog.confirmed.connect(_on_confirm_delete_data)
	
	# 5. Connect Character Buttons
	# Check if nodes exist to avoid errors if you have less than 4 buttons created
	if btn_char_1: btn_char_1.pressed.connect(func(): _on_character_selected("tor_ob1"))
	if btn_char_2: btn_char_2.pressed.connect(func(): _on_character_selected("kat"))
	if btn_char_3: btn_char_3.pressed.connect(func(): _on_character_selected("zzokrugug"))
	if btn_char_4: btn_char_4.pressed.connect(func(): _on_character_selected("irvikktiti"))
	if btn_char_5: btn_char_5.pressed.connect(func(): _on_character_selected("krofhon"))
	if btn_char_6: btn_char_6.pressed.connect(func(): _on_character_selected("shaqur"))
	if btn_char_7: btn_char_7.pressed.connect(func(): _on_character_selected("khormol"))
	if btn_char_8: btn_char_8.pressed.connect(func(): _on_character_selected("perma"))
	if btn_char_9: btn_char_9.pressed.connect(func(): _on_character_selected("vigo"))
	if btn_char_10: btn_char_10.pressed.connect(func(): _on_character_selected("fram"))
	if btn_char_11: btn_char_11.pressed.connect(func(): _on_character_selected("naerum"))
	if btn_char_12: btn_char_12.pressed.connect(func(): _on_character_selected("sulphura"))
	if btn_char_13: btn_char_13.pressed.connect(func(): _on_character_selected("sseroghol"))
	if btn_char_14: btn_char_14.pressed.connect(func(): _on_character_selected("hojo"))
	if btn_char_15: btn_char_15.pressed.connect(func(): _on_character_selected("guhulgghuru"))
	if btn_char_16: btn_char_16.pressed.connect(func(): _on_character_selected("omocqitheqq"))
	if btn_char_17: btn_char_17.pressed.connect(func(): _on_character_selected("allucard"))
	if btn_char_18: btn_char_18.pressed.connect(func(): _on_character_selected("liv, ficu & aduj"))
	if btn_char_19: btn_char_19.pressed.connect(func(): _on_character_selected("gnarlhom"))
	
	# Initial Focus
	button_start.grab_focus()
	
	GameData.load_bank()

# --- MAIN LEVEL FUNCTIONS ---

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_shop_pressed() -> void:
	shop_menu.show()
	button_close_shop.grab_focus()

func _on_forge_pressed() -> void:
	forge_menu.show()
	button_close_forge.grab_focus()

func _on_open_char_select_pressed() -> void:
	char_select_menu.show()
	# Option: Select the first char by default when opening
	_on_character_selected("char1")
	# Focus the first character button so we can navigate with keyboard immediately
	if btn_char_1: btn_char_1.grab_focus()

func _on_close_main_sub_menus() -> void:
	shop_menu.hide()
	forge_menu.hide()
	char_select_menu.hide()
	button_start.grab_focus()

# --- CHARACTER SELECT FUNCTIONS ---

func _open_popup(popup_to_show: Panel, button_to_focus: Button) -> void:
	popup_to_show.show()
	button_to_focus.grab_focus()

func _close_all_popups() -> void:
	customize_popup.hide()
	mode_popup.hide()
	challenge_popup.hide()
	btn_start_game.grab_focus()

func _on_start_game_pressed() -> void:
	# Change la scène actuelle pour charger la scène de Jeu
	get_tree().change_scene_to_file("res://Scenes/World/Game.tscn")

# Updates the info panel based on the selected character key
func _on_character_selected(char_id: String) -> void:
	GameData.selected_character_id = char_id

func _on_button_parameters_pressed():
	parameters_menu.show()

func _on_close_params_pressed():
	parameters_menu.hide()

func _on_reset_save_pressed():
	# On affiche la pop-up de confirmation au centre de l'écran
	delete_confirm_dialog.popup_centered()

func _on_confirm_delete_data():
	# L'utilisateur a cliqué sur "Oui"
	GameData.delete_save()
	
	# Optionnel : Si la boutique était ouverte en arrière-plan ou si tu affiches l'or ailleurs,
	# il faudrait rafraîchir l'interface ici.
	# Par exemple, si tu as une méthode pour update l'UI du menu principal :
	# refresh_main_ui() 
	parameters_menu.hide() # On ferme le menu après l'action
