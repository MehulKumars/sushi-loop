extends Screen
## Credits from ATTRIBUTION.md (headings and lines of a small markdown file turned into BBCode),
## then the licence texts the shipped code requires: Godot's MIT licence and its third-party parts.
## Links are shown as plain text, so a tap never opens a browser by accident.

const ATTRIBUTION: String = "res://ATTRIBUTION.md"
## Font size per markdown heading level (#, ##, ###, ####).
const HEADING_SIZES: Array[int] = [52, 42, 34, 30]


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	var label: RichTextLabel = %CreditsText
	label.text = ""
	label.append_text(markdown_to_bbcode(FileAccess.get_file_as_string(ATTRIBUTION)))
	label.append_text("\n\n" + _licences())


## Headings become bold lines at HEADING_SIZES; other lines stay as they are (two trailing
## spaces, markdown's line break, are dropped). The first "# " title is skipped: the screen has one.
static func markdown_to_bbcode(text: String) -> String:
	var out: PackedStringArray = []
	var skipped_title := false
	for raw in text.replace("\r\n", "\n").split("\n"):
		var line := raw.strip_edges()
		var level := 0
		while level < line.length() and line[level] == "#":
			level += 1
		if level == 1 and not skipped_title:
			skipped_title = true
			continue
		if level > 0:
			var size := HEADING_SIZES[mini(level, HEADING_SIZES.size()) - 1]
			if not out.is_empty():
				out.append("")
			out.append("[font_size=%d][b]%s[/b][/font_size]" % [size, line.substr(level).strip_edges()])
		elif not line.is_empty():
			out.append(line.replace("[", "[lb]"))
	return "\n".join(out)


## Licence notices. The font (OFL) and icon (Apache) licence files ship in the app as well.
func _licences() -> String:
	var lines: PackedStringArray = ["[font_size=40][b]Licences[/b][/font_size]", ""]
	lines.append("[b]Godot Engine[/b]")
	lines.append("[font_size=22]%s[/font_size]" % _unwrap(Engine.get_license_text()))
	lines.append("")
	lines.append("[b]Parts of Godot Engine[/b]")
	var parts: PackedStringArray = []
	for info: Dictionary in Engine.get_copyright_info():
		var licenses: PackedStringArray = []
		for part: Dictionary in info.parts:
			if not licenses.has(part.license):
				licenses.append(part.license)
		parts.append("%s: %s" % [info.name, ", ".join(licenses)])
	lines.append("[font_size=22]%s[/font_size]" % "\n".join(parts))
	return "\n".join(lines)


## Licence files break lines at 80 characters; join them into paragraphs so they wrap cleanly.
static func _unwrap(text: String) -> String:
	var paragraphs := text.strip_edges().replace("\r\n", "\n").split("\n\n")
	var joined: PackedStringArray = []
	for paragraph in paragraphs:
		joined.append(" ".join(paragraph.split("\n")).strip_edges())
	return "\n\n".join(joined)
