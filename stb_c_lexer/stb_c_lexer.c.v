module stb_c_lexer

#flag -I @VMODROOT/stb_c_lexer
#define STB_C_LEXER_IMPLEMENTATION
#include "stb_c_lexer.h"

pub struct Lexer {
pub:
	input_stream       &char = unsafe { nil }
	eof                &char = unsafe { nil }
	parse_point        &char = unsafe { nil }
	string_storage     &char = unsafe { nil }
	string_storage_len int
	where_firstchar    &char = unsafe { nil }
	where_lastchar     &char = unsafe { nil }
	token              int
	real_number        f64
	int_number         int
	string             &char = unsafe { nil }
	string_len         int
}

pub struct Location {
pub:
	line_number int
	line_offset int
}

fn C.stb_c_lexer_init(lexer &Lexer, input_stream &char, input_stream_end &char, string_store &char, store_length int)

pub fn init(lexer &Lexer, input_stream &char, input_stream_end &char, string_store &char, store_length int) {
	C.stb_c_lexer_init(lexer, input_stream, input_stream_end, string_store, store_length)
}

fn C.stb_c_lexer_get_token(lexer &Lexer) int

pub fn get_token(lexer &Lexer) int {
	return C.stb_c_lexer_get_token(lexer)
}

fn C.stb_c_lexer_get_location(lexer &Lexer, where &char, loc &Location)

pub fn get_location(lexer &Lexer, where &char, loc &Location) {
	C.stb_c_lexer_get_location(lexer, where, loc)
}

pub const clex_eof = 256
pub const clex_parse_error = 257
pub const clex_intlit = 258
pub const clex_floatlit = 259
pub const clex_id = 260
pub const clex_dqstring = 261
pub const clex_sqstring = 262
pub const clex_charlit = 263
pub const clex_eq = 264
pub const clex_noteq = 265
pub const clex_lesseq = 266
pub const clex_greatereq = 267
pub const clex_andand = 268
pub const clex_oror = 269
pub const clex_shl = 270
pub const clex_shr = 271
pub const clex_plusplus = 272
pub const clex_minusminus = 273
pub const clex_pluseq = 274
pub const clex_minuseq = 275
pub const clex_muleq = 276
pub const clex_diveq = 277
pub const clex_modeq = 278
pub const clex_andeq = 279
pub const clex_oreq = 280
pub const clex_xoreq = 281
pub const clex_arrow = 282
pub const clex_eqarrow = 283
pub const clex_shleq = 284
pub const clex_shreq = 285
pub const clex_first_unused_token = 286
