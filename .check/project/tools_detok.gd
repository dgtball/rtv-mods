extends SceneTree

const _GDSC_TOKEN_MASK := (1 << 7) - 1
const _GDSC_TOKEN_SHIFT := 7
const _GDSC_TOKEN_BYTE_MASK := 0x80
const V100 := 100
const V101 := 101

const _TOKEN_TEXT := {
	4: "<", 5: "<=", 6: ">", 7: ">=", 8: "==", 9: "!=",
	10: "and", 11: "or", 12: "not", 13: "&&", 14: "||", 15: "!",
	16: "&", 17: "|", 18: "~", 19: "^", 20: "<<", 21: ">>",
	22: "+", 23: "-", 24: "*", 25: "**", 26: "/", 27: "%",
	28: "=", 29: "+=", 30: "-=", 31: "*=", 32: "**=", 33: "/=",
	34: "%=", 35: "<<=", 36: ">>=", 37: "&=", 38: "|=", 39: "^=",
	40: "if", 41: "elif", 42: "else", 43: "for", 44: "while",
	45: "break", 46: "continue", 47: "pass", 48: "return", 49: "match", 50: "when",
	51: "as", 52: "assert", 53: "await", 54: "breakpoint", 55: "class",
	56: "class_name", 57: "const", 58: "enum", 59: "extends", 60: "func",
	61: "in", 62: "is", 63: "namespace", 64: "preload", 65: "self",
	66: "signal", 67: "static", 68: "super", 69: "trait", 70: "var",
	71: "void", 72: "yield",
	73: "[", 74: "]", 75: "{", 76: "}", 77: "(", 78: ")",
	79: ",", 80: ";", 81: ".", 82: "..", 83: "...",
	84: ":", 85: "$", 86: "->", 87: "_",
	91: "PI", 92: "TAU", 93: "INF", 94: "NAN",
	96: "`", 97: "?",
}

const _SPACE_BEFORE := {
	4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1,
	10: 1, 11: 1, 12: 1, 13: 1, 14: 1,
	16: 1, 17: 1, 19: 1, 20: 1, 21: 1,
	22: 1, 23: 1, 24: 1, 25: 1, 26: 1, 27: 1,
	28: 1, 29: 1, 30: 1, 31: 1, 32: 1, 33: 1,
	34: 1, 35: 1, 36: 1, 37: 1, 38: 1, 39: 1,
	40: 1, 42: 1, 51: 1, 61: 1, 62: 1,
	86: 1,
}

const _SPACE_AFTER := {
	79: 1, 80: 1, 86: 1,
	4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1,
	10: 1, 11: 1, 12: 1, 13: 1, 14: 1, 15: 1,
	16: 1, 17: 1, 19: 1, 20: 1, 21: 1,
	22: 1, 23: 1, 24: 1, 25: 1, 26: 1, 27: 1,
	28: 1, 29: 1, 30: 1, 31: 1, 32: 1, 33: 1,
	34: 1, 35: 1, 36: 1, 37: 1, 38: 1, 39: 1,
	84: 1,
	1: 1,
	40: 1, 41: 1, 42: 1, 43: 1, 44: 1,
	45: 1, 46: 1, 47: 1, 48: 1, 49: 1, 50: 1,
	51: 1, 52: 1, 53: 1, 54: 1, 55: 1,
	56: 1, 57: 1, 58: 1, 59: 1, 60: 1,
	61: 1, 62: 1, 63: 1, 64: 1, 65: 1,
	66: 1, 67: 1, 68: 1, 69: 1, 70: 1,
	71: 1, 72: 1,
}

const TK_ANNOTATION := 1
const TK_IDENTIFIER := 2
const TK_LITERAL := 3
const TK_NOT := 12
const TK_BANG := 15
const TK_TILDE := 18
const TK_KW_FIRST := 40
const TK_KW_WHEN := 50
const TK_KW_LAST := 72
const TK_BRACKET_OPEN := 73
const TK_BRACE_CLOSE := 76
const TK_PAREN_OPEN := 77
const TK_PAREN_CLOSE := 78
const TK_DOT := 81
const TK_DOLLAR := 85
const TK_UNDERSCORE := 87
const TK_NEWLINE := 88
const TK_INDENT := 89
const TK_DEDENT := 90
const TK_PI := 91
const TK_TAU := 92
const TK_INF := 93
const TK_NAN := 94
const TK_EOF := 99


func decode_sections(buf: PackedByteArray, version: int) -> Dictionary:
	var meta_size := 20 if version == V100 else 16
	if buf.size() < meta_size:
		return {}
	var ident_count: int = buf.decode_u32(0)
	var const_count: int = buf.decode_u32(4)
	var line_count: int = buf.decode_u32(8)
	var token_count: int
	if version == V100:
		token_count = buf.decode_u32(16)
	else:
		token_count = buf.decode_u32(12)
	var offset := meta_size

	var identifiers: Array[String] = []
	for _i in ident_count:
		if offset + 4 > buf.size():
			break
		var str_len: int = buf.decode_u32(offset)
		offset += 4
		var s := ""
		for _j in str_len:
			if offset + 4 > buf.size():
				break
			var b0: int = buf[offset] ^ 0xb6
			var b1: int = buf[offset + 1] ^ 0xb6
			var b2: int = buf[offset + 2] ^ 0xb6
			var b3: int = buf[offset + 3] ^ 0xb6
			var code_point: int = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
			if code_point > 0:
				s += String.chr(code_point)
			offset += 4
		identifiers.append(s)

	var constants: Array = []
	for _i in const_count:
		if offset + 4 > buf.size():
			break
		var remaining := buf.slice(offset)
		var val = bytes_to_var(remaining)
		if val == null and constants.size() == 0:
			# bytes_to_var of plain null; advance by null encoding size (8: marker type + int 0)
			offset += 8
			constants.append(null)
			continue
		constants.append(val)
		var encoded := var_to_bytes(val)
		offset += encoded.size()

	var line_map := {}
	var col_map := {}
	for _i in line_count:
		if offset + 8 > buf.size():
			break
		var tok_idx: int = buf.decode_u32(offset)
		var line_val: int = buf.decode_u32(offset + 4)
		line_map[tok_idx] = line_val
		offset += 8
	for _i in line_count:
		if offset + 8 > buf.size():
			break
		var tok_idx: int = buf.decode_u32(offset)
		var col_val: int = buf.decode_u32(offset + 4)
		col_map[tok_idx] = col_val
		offset += 8

	var tokens: Array = []
	for _i in token_count:
		if offset >= buf.size():
			break
		var token_len := 8 if (buf[offset] & _GDSC_TOKEN_BYTE_MASK) else 5
		if offset + token_len > buf.size():
			break
		var raw_type: int = buf.decode_u32(offset)
		var tk_type: int = raw_type & _GDSC_TOKEN_MASK
		if version == V100 and tk_type >= 83:
			tk_type += 1
		var data_idx: int = raw_type >> _GDSC_TOKEN_SHIFT
		tokens.append([tk_type, data_idx])
		offset += token_len

	if identifiers.size() != ident_count or constants.size() != const_count or tokens.size() != token_count:
		print("DESYNC idents %d/%d consts %d/%d tokens %d/%d" % [identifiers.size(), ident_count, constants.size(), const_count, tokens.size(), token_count])
		return {}
	return {"identifiers": identifiers, "constants": constants, "line_map": line_map, "col_map": col_map, "tokens": tokens}


func indent_from_column(col: int) -> int:
	@warning_ignore("integer_division")
	return col / 4


func variant_to_source(value: Variant) -> String:
	if value == null:
		return "null"
	match typeof(value):
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			if is_inf(value):
				return "INF" if value > 0.0 else "-INF"
			if is_nan(value):
				return "NAN"
			var s := str(value)
			if "." not in s and "e" not in s:
				s += ".0"
			return s
		TYPE_STRING:
			return '"%s"' % str(value).c_escape()
		TYPE_STRING_NAME:
			return '&"%s"' % str(value).c_escape()
		TYPE_NODE_PATH:
			return '^"%s"' % str(value).c_escape()
		_:
			return "null"


func reconstruct(tokens: Array, identifiers: Array[String], constants: Array, line_map: Dictionary, col_map: Dictionary) -> String:
	var lines := PackedStringArray()
	var current_line := ""
	var current_line_num := 1
	var need_space := false
	var prev_tk := -1
	var line_started := false

	for i in tokens.size():
		var tk: int = tokens[i][0]
		var idx: int = tokens[i][1]

		if line_map.has(i):
			var new_line: int = line_map[i]
			if new_line - current_line_num > 10000:
				print("absurd line jump")
				return ""
			while current_line_num < new_line:
				lines.append(current_line)
				current_line = ""
				current_line_num += 1
				need_space = false
				line_started = false

		if tk == TK_EOF:
			break
		if tk == TK_NEWLINE:
			lines.append(current_line)
			current_line = ""
			current_line_num += 1
			need_space = false
			line_started = false
			prev_tk = tk
			continue
		if tk == TK_INDENT or tk == TK_DEDENT:
			prev_tk = tk
			continue
		if tk == 0:
			continue

		var text := ""
		if tk == TK_IDENTIFIER:
			text = identifiers[idx] if idx < identifiers.size() else "<ident?>"
		elif tk == TK_ANNOTATION:
			var aname: String = identifiers[idx] if idx < identifiers.size() else "?"
			text = aname if aname.begins_with("@") else ("@" + aname)
		elif tk == TK_LITERAL:
			text = variant_to_source(constants[idx] if idx < constants.size() else null)
		elif _TOKEN_TEXT.has(tk):
			text = _TOKEN_TEXT[tk]
		else:
			text = "<tk%d>" % tk

		if not line_started:
			line_started = true
			if col_map.has(i):
				var col: int = col_map[i]
				var tabs: int = indent_from_column(col)
				for _t in tabs:
					current_line += "\t"

		var add_space_before := false
		if need_space and not current_line.is_empty() and not current_line.ends_with("\t"):
			if _SPACE_BEFORE.has(tk):
				add_space_before = true
			elif tk == TK_IDENTIFIER or tk == TK_LITERAL or tk == TK_ANNOTATION or (tk >= TK_KW_FIRST and tk <= TK_KW_LAST):
				var skip_anno := (prev_tk == TK_ANNOTATION and (tk == TK_IDENTIFIER or tk == TK_ANNOTATION))
				if not skip_anno \
						and prev_tk != TK_PAREN_OPEN and prev_tk != TK_BRACKET_OPEN \
						and prev_tk != TK_DOT and prev_tk != TK_DOLLAR \
						and prev_tk != TK_TILDE \
						and prev_tk != TK_BANG and prev_tk != TK_INDENT \
						and prev_tk != TK_NEWLINE and prev_tk != -1:
					add_space_before = true
			elif tk == TK_PAREN_OPEN:
				if prev_tk >= TK_KW_FIRST and prev_tk <= TK_KW_WHEN:
					add_space_before = true
			elif tk == TK_NOT or tk == TK_BANG:
				add_space_before = true

		if add_space_before and not current_line.ends_with(" ") and not current_line.ends_with("\t"):
			current_line += " "

		current_line += text
		need_space = _SPACE_AFTER.has(tk) or tk == TK_IDENTIFIER or tk == TK_LITERAL \
				or tk == TK_PAREN_CLOSE or tk == 74 or tk == TK_BRACE_CLOSE \
				or tk == TK_PI or tk == TK_TAU or tk == TK_INF \
				or tk == TK_NAN or tk == TK_UNDERSCORE

		prev_tk = tk

	if not current_line.is_empty():
		lines.append(current_line)

	var result := "\n".join(lines)
	if not result.ends_with("\n"):
		result += "\n"
	return result


func detok(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("cannot open " + path)
		return ""
	var raw := f.get_buffer(f.get_length())
	f.close()
	if raw.size() < 12:
		return ""
	var magic := raw.slice(0, 4).get_string_from_ascii()
	if magic != "GDSC":
		print("not GDSC")
		return ""
	var version := raw.decode_u32(4)
	var decompressed_size := raw.decode_u32(8)
	var buf: PackedByteArray
	if decompressed_size == 0:
		buf = raw.slice(12)
	else:
		buf = raw.slice(12).decompress(decompressed_size, FileAccess.COMPRESSION_ZSTD)
	var sections := decode_sections(buf, version)
	if sections.is_empty():
		return ""
	return reconstruct(sections["tokens"], sections["identifiers"], sections["constants"],
			sections["line_map"], sections["col_map"])


func _init() -> void:
	var args := OS.get_cmdline_args()
	var path := "D:/RTVMOD/RTVcopy/extracted/Scripts/Optic.gdc"
	for a in args:
		if a.begins_with("--in "):
			path = a.substr(5)
	var src := detok(path)
	var f2 := FileAccess.open("C:/Users/home/AppData/Local/Temp/opencode/detok_out.txt", FileAccess.WRITE)
	if f2 != null:
		f2.store_string(src)
		f2.close()
	print("DETOK_DONE chars=" + str(src.length()))
	quit(0)
