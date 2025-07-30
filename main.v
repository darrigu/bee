module main

import os
import stb_c_lexer

const file_path = 'hello.bee'

fn expect_token(l &stb_c_lexer.Lexer, token int) ? {
	if l.token != token {
		loc := stb_c_lexer.Location{}
		stb_c_lexer.get_location(l, l.where_firstchar, &loc)
		eprintln('${file_path}:${loc.line_number}:${loc.line_offset + 1}: error: expected token ${token}, but got ${l.token}')
		return none
	}
}

fn get_and_expect_token(l &stb_c_lexer.Lexer, token int) ? {
	stb_c_lexer.get_token(l)
	return expect_token(l, token)
}

struct Var {
	name  string
	index int
	where &char
}

fn run() ? {
	mut vars := map[string]Var{}
	mut auto_vars_count := 0

	contents := os.read_file(file_path) or {
		eprintln('error: ${err.msg()}: ${os.get_error_msg(err.code()).to_lower()}')
		return none
	}

	l := stb_c_lexer.Lexer{}
	string_store := []u8{len: 1024}
	stb_c_lexer.init(&l, contents.str, unsafe { contents.str + contents.len }, string_store.data,
		string_store.len)

	println('format ELF64')
	println('section ".text" executable')

	for {
		vars.clear()
		auto_vars_count = 0

		stb_c_lexer.get_token(&l)
		if l.token == stb_c_lexer.clex_eof {
			break
		}

		expect_token(&l, stb_c_lexer.clex_id)?
		symbol_name := unsafe { cstring_to_vstring(l.string) }
		println('public ${symbol_name}')
		println('${symbol_name}:')
		get_and_expect_token(&l, int(`(`))?
		get_and_expect_token(&l, int(`)`))?
		get_and_expect_token(&l, int(`{`))?

		println('  push rbp')
		println('  mov rbp, rsp')

		for {
			stb_c_lexer.get_token(&l)
			if l.token == int(`}`) {
				println('  mov rsp, rbp')
				println('  pop rbp')
				println('  mov rax, 0')
				println('  ret')
				break
			}
			expect_token(&l, stb_c_lexer.clex_id)?
			match unsafe { l.string.vstring() } {
				'extrn' {
					get_and_expect_token(&l, stb_c_lexer.clex_id)?
					name := unsafe { cstring_to_vstring(l.string) }
					println('  extrn ${name}')
					get_and_expect_token(&l, int(`;`))?
				}
				'auto' {
					get_and_expect_token(&l, stb_c_lexer.clex_id)?
					auto_vars_count += 1
					name := unsafe { cstring_to_vstring(l.string) }
					name_where := l.where_firstchar
					if existing := vars[name] {
						loc := stb_c_lexer.Location{}
						stb_c_lexer.get_location(&l, name_where, &loc)
						eprintln('${file_path}:${loc.line_number}:${loc.line_offset + 1}: error: variable ${existing.name} has already been defined')
						stb_c_lexer.get_location(&l, existing.where, &loc)
						eprintln('${file_path}:${loc.line_number}:${loc.line_offset + 1}: info: first definition is located here')
						return none
					}
					vars[name] = Var{
						name:  name
						index: auto_vars_count
						where: name_where
					}
					println('  sub rsp, 8')
					get_and_expect_token(&l, int(`;`))?
				}
				else {
					name := unsafe { cstring_to_vstring(l.string) }
					name_where := l.where_firstchar
					stb_c_lexer.get_token(&l)
					match l.token {
						int(`=`) {
							var := vars[name] or {
								loc := stb_c_lexer.Location{}
								stb_c_lexer.get_location(&l, name_where, &loc)
								eprintln('${file_path}:${loc.line_number}:${loc.line_offset + 1}: error: variable ${name} does not exist')
								return none
							}

							get_and_expect_token(&l, stb_c_lexer.clex_intlit)?
							println('  mov QWORD [rbp-${var.index * 8}], ${l.int_number}')
							get_and_expect_token(&l, int(`;`))?
						}
						int(`(`) {
							stb_c_lexer.get_token(&l)
							if l.token != int(`)`) {
								expect_token(&l, stb_c_lexer.clex_id)
								var_name := unsafe { cstring_to_vstring(l.string) }
								var_name_where := l.where_firstchar
								var := vars[var_name] or {
									loc := stb_c_lexer.Location{}
									stb_c_lexer.get_location(&l, var_name_where, &loc)
									eprintln('${file_path}:${loc.line_number}:${loc.line_offset + 1}: error: variable ${var_name} does not exist')
									return none
								}

								println('  mov rdi, [rbp-${var.index * 8}]')
								get_and_expect_token(&l, int(`)`))?
							}

							println('  call ${name}')
							get_and_expect_token(&l, int(`;`))?
						}
						else {
							loc := stb_c_lexer.Location{}
							stb_c_lexer.get_location(l, l.where_firstchar, &loc)
							eprintln('${file_path}:${loc.line_number}:${loc.line_offset + 1}: error: unexpected token ${l.token}')
							return none
						}
					}
				}
			}
		}
	}
}

fn main() {
	run() or { exit(1) }
}
