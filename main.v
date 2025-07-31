module main

import os
import stb_c_lexer

fn diag(l &stb_c_lexer.Lexer, path string, where &char, message string) {
	loc := stb_c_lexer.Location{}
	stb_c_lexer.get_location(l, where, &loc)
	eprintln('${path}:${loc.line_number}:${loc.line_offset + 1}: ${message}')
}

fn expect_token(l &stb_c_lexer.Lexer, input_path string, token int) ? {
	if l.token != token {
		diag(l, input_path, l.where_firstchar, 'error: expected token ${token}, but got ${l.token}')
		return none
	}
}

fn get_and_expect_token(l &stb_c_lexer.Lexer, input_path string, token int) ? {
	stb_c_lexer.get_token(l)
	return expect_token(l, input_path, token)
}

struct Var {
	name  string
	index int
	where &char
}

fn shift[T](mut arr []T) T {
	first := arr.first()
	arr.delete(0)
	return first
}

fn usage(mut file os.File) {
	file.writeln('Usage: bee <input.bee>') or {}
}

fn run() ? {
	mut args := os.args.clone()

	shift(mut args)

	if args.len == 0 {
		mut stderr := os.stderr()
		usage(mut stderr)
		eprintln('error: no input file path was provided')
		return none
	}

	input_path := shift(mut args)

	mut vars := map[string]Var{}
	mut auto_vars_count := 0

	contents := os.read_file(input_path) or {
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

		expect_token(&l, input_path, stb_c_lexer.clex_id)?
		symbol_name := unsafe { cstring_to_vstring(l.string) }
		println('public ${symbol_name}')
		println('${symbol_name}:')
		get_and_expect_token(&l, input_path, int(`(`))?
		get_and_expect_token(&l, input_path, int(`)`))?
		get_and_expect_token(&l, input_path, int(`{`))?

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
			expect_token(&l, input_path, stb_c_lexer.clex_id)?
			match unsafe { l.string.vstring() } {
				'extrn' {
					get_and_expect_token(&l, input_path, stb_c_lexer.clex_id)?
					name := unsafe { cstring_to_vstring(l.string) }
					println('  extrn ${name}')
					get_and_expect_token(&l, input_path, int(`;`))?
				}
				'auto' {
					get_and_expect_token(&l, input_path, stb_c_lexer.clex_id)?
					auto_vars_count += 1
					name := unsafe { cstring_to_vstring(l.string) }
					name_where := l.where_firstchar
					if existing := vars[name] {
						diag(l, input_path, name_where, 'error: variable ${existing.name} has already been defined')
						diag(l, input_path, existing.where, 'info: first definition is located here')
						return none
					}
					vars[name] = Var{
						name:  name
						index: auto_vars_count
						where: name_where
					}
					println('  sub rsp, 8')
					get_and_expect_token(&l, input_path, int(`;`))?
				}
				else {
					name := unsafe { cstring_to_vstring(l.string) }
					name_where := l.where_firstchar
					stb_c_lexer.get_token(&l)
					match l.token {
						int(`=`) {
							var := vars[name] or {
								diag(&l, input_path, name_where, 'error: variable ${name} does not exist')
								return none
							}

							get_and_expect_token(&l, input_path, stb_c_lexer.clex_intlit)?
							println('  mov QWORD [rbp-${var.index * 8}], ${l.int_number}')
							get_and_expect_token(&l, input_path, int(`;`))?
						}
						int(`(`) {
							stb_c_lexer.get_token(&l)
							if l.token != int(`)`) {
								expect_token(&l, input_path, stb_c_lexer.clex_id)
								var_name := unsafe { cstring_to_vstring(l.string) }
								var_name_where := l.where_firstchar
								var := vars[var_name] or {
									diag(&l, input_path, var_name_where, 'error: variable ${var_name} does not exist')
									return none
								}

								println('  mov rdi, [rbp-${var.index * 8}]')
								get_and_expect_token(&l, input_path, int(`)`))?
							}

							println('  call ${name}')
							get_and_expect_token(&l, input_path, int(`;`))?
						}
						else {
							diag(&l, input_path, l.where_firstchar, 'error: unexpected token ${l.token}')
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
