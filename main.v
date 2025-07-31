module main

import os
import flag
import strings
import stb_c_lexer

fn diag(l &stb_c_lexer.Lexer, path string, where &char, message string) {
	loc := stb_c_lexer.Location{}
	stb_c_lexer.get_location(l, where, &loc)
	eprintln('${path}:${loc.line_number}:${loc.line_offset + 1}: ${message}')
}

fn todo(l &stb_c_lexer.Lexer, path string, where &char, src_loc string, message string) {
	loc := stb_c_lexer.Location{}
	stb_c_lexer.get_location(l, where, &loc)
	eprintln('${path}:${loc.line_number}:${loc.line_offset + 1}: todo: ${message}')
	eprintln('${src_loc}: info: implementation should go here')
	exit(1)
}

fn token_to_str(token int) string {
	match token {
		stb_c_lexer.clex_intlit {
			return 'integer literal'
		}
		stb_c_lexer.clex_floatlit {
			return 'floating-point literal'
		}
		stb_c_lexer.clex_id {
			return 'identifier'
		}
		stb_c_lexer.clex_dqstring {
			return 'double-quoted string'
		}
		stb_c_lexer.clex_sqstring {
			return 'single-quoted string'
		}
		stb_c_lexer.clex_charlit {
			return 'character literal'
		}
		stb_c_lexer.clex_eq {
			return '`=`'
		}
		stb_c_lexer.clex_noteq {
			return '`!=`'
		}
		stb_c_lexer.clex_lesseq {
			return '`<=`'
		}
		stb_c_lexer.clex_greatereq {
			return '`>=`'
		}
		stb_c_lexer.clex_andand {
			return '`&&`'
		}
		stb_c_lexer.clex_oror {
			return '`||`'
		}
		stb_c_lexer.clex_shl {
			return '`<<`'
		}
		stb_c_lexer.clex_shr {
			return '`>>`'
		}
		stb_c_lexer.clex_plusplus {
			return '`++`'
		}
		stb_c_lexer.clex_minusminus {
			return '`--`'
		}
		stb_c_lexer.clex_pluseq {
			return '`+=`'
		}
		stb_c_lexer.clex_minuseq {
			return '`-=`'
		}
		stb_c_lexer.clex_muleq {
			return '`*=`'
		}
		stb_c_lexer.clex_diveq {
			return '`/=`'
		}
		stb_c_lexer.clex_modeq {
			return '`%=`'
		}
		stb_c_lexer.clex_andeq {
			return '`&=`'
		}
		stb_c_lexer.clex_oreq {
			return '`|=`'
		}
		stb_c_lexer.clex_xoreq {
			return '`^=`'
		}
		stb_c_lexer.clex_arrow {
			return '`->`'
		}
		stb_c_lexer.clex_eqarrow {
			return '`=>`'
		}
		stb_c_lexer.clex_shleq {
			return '`<<=`'
		}
		stb_c_lexer.clex_shreq {
			return '`>>=`'
		}
		else {
			if token < 256 {
				return '`${rune(token)}`'
			} else {
				return '<<<UNKNOWN TOKEN ${token}>>>'
			}
		}
	}
}

fn expect_token(l &stb_c_lexer.Lexer, input_path string, token int) ? {
	if l.token != token {
		diag(l, input_path, l.where_firstchar, 'error: expected ${token_to_str(token)}, but got ${token_to_str(l.token)}')
		return none
	}
}

fn get_and_expect_token(l &stb_c_lexer.Lexer, input_path string, token int) ? {
	stb_c_lexer.get_token(l)
	return expect_token(l, input_path, token)
}

enum Storage {
	external
	auto
}

struct Var {
	name    string  @[required]
	storage Storage @[required]
	index   int     @[required]
	where   &char   @[required]
}

fn shift[T](mut arr []T) T {
	first := arr.first()
	arr.delete(0)
	return first
}

struct Config {
	output_path string @[long: output; short: o; xdoc: 'Set output file path']
	show_help   bool   @[long: help; short: h; xdoc: 'Print this help message']
}

fn print_help(mut file os.File) {
	usage := 'Usage: bee <input.bee> -o <output.asm>'
	help := flag.to_doc[Config](
		description: usage
		options:     flag.DocOptions{
			flag_header: 'Options:'
			compact:     true
		}
	) or { usage }
	file.writeln(help) or {}
}

fn run() ? {
	config, no_matches := flag.to_struct[Config](os.args, skip: 1) or {
		eprintln('error: ${err}')
		return none
	}

	mut maybe_input_path := ?string(none)

	for no_match in no_matches {
		if no_match.starts_with('-') {
			eprintln('error: unknown flag `${no_match}`')
			return none
		}
		maybe_input_path = no_match
	}

	if config.show_help {
		mut stdout := os.stdout()
		print_help(mut stdout)
		exit(0)
	}

	input_path := maybe_input_path or {
		mut stderr := os.stderr()
		print_help(mut stderr)
		eprintln('error: no input file path was provided')
		return none
	}

	if config.output_path == '' {
		mut stderr := os.stderr()
		print_help(mut stderr)
		eprintln('error: no output file path was provided')
		return none
	}

	mut vars := map[string]Var{}
	mut auto_vars_count := 0

	input := os.read_file(input_path) or {
		eprintln('error: ${err.msg()}: ${os.get_error_msg(err.code()).to_lower()}')
		return none
	}

	l := stb_c_lexer.Lexer{}
	string_store := []u8{len: 1024}
	stb_c_lexer.init(&l, input.str, unsafe { input.str + input.len }, string_store.data,
		string_store.len)

	mut output := strings.new_builder(0)
	output.writeln('format ELF64')
	output.writeln('section ".text" executable')

	for {
		vars.clear()
		auto_vars_count = 0

		stb_c_lexer.get_token(&l)
		if l.token == stb_c_lexer.clex_eof {
			break
		}

		expect_token(&l, input_path, stb_c_lexer.clex_id)?

		stb_c_lexer.get_token(&l)
		if l.token == int(`(`) {
			get_and_expect_token(&l, input_path, int(`)`))?
			get_and_expect_token(&l, input_path, int(`{`))?

			symbol_name := unsafe { cstring_to_vstring(l.string) }
			output.writeln('public ${symbol_name}')
			output.writeln('${symbol_name}:')
			output.writeln('  push rbp')
			output.writeln('  mov rbp, rsp')

			for {
				stb_c_lexer.get_token(&l)
				if l.token == int(`}`) {
					output.writeln('  mov rsp, rbp')
					output.writeln('  pop rbp')
					output.writeln('  mov rax, 0')
					output.writeln('  ret')
					break
				}
				expect_token(&l, input_path, stb_c_lexer.clex_id)?
				match unsafe { l.string.vstring() } {
					'extrn' {
						get_and_expect_token(&l, input_path, stb_c_lexer.clex_id)?

						name := unsafe { cstring_to_vstring(l.string) }
						name_where := l.where_firstchar
						if existing := vars[name] {
							diag(l, input_path, name_where, 'error: variable ${existing.name} has already been defined')
							diag(l, input_path, existing.where, 'info: first definition is located here')
							return none
						}

						vars[name] = Var{
							name:    name
							storage: .external
							index:   0
							where:   name_where
						}

						output.writeln('  extrn ${name}')
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
							name:    name
							storage: .auto
							index:   auto_vars_count
							where:   name_where
						}

						output.writeln('  sub rsp, 8')
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
								match var.storage {
									.external {
										todo(l, input_path, name_where, @FILE_LINE, 'assignment to external variables')
									}
									.auto {
										output.writeln('  mov QWORD [rbp-${var.index * 8}], ${l.int_number}')
									}
								}

								get_and_expect_token(&l, input_path, int(`;`))?
							}
							int(`(`) {
								func := vars[name] or {
									diag(&l, input_path, name_where, 'error: function ${name} does not exist')
									return none
								}

								stb_c_lexer.get_token(&l)
								if l.token != int(`)`) {
									expect_token(&l, input_path, stb_c_lexer.clex_id)
									var_name := unsafe { cstring_to_vstring(l.string) }
									var := vars[var_name] or {
										diag(&l, input_path, l.where_firstchar, 'error: variable ${var_name} does not exist')
										return none
									}

									output.writeln('  mov rdi, [rbp-${var.index * 8}]')
									get_and_expect_token(&l, input_path, int(`)`))?
								}

								match func.storage {
									.external {
										output.writeln('  call ${name}')
									}
									.auto {
										todo(&l, input_path, name_where, @FILE_LINE, 'calling function from auto variable')
									}
								}

								get_and_expect_token(&l, input_path, int(`;`))?
							}
							else {
								diag(&l, input_path, l.where_firstchar, 'error: unexpected ${token_to_str(l.token)}')
								return none
							}
						}
					}
				}
			}
		} else {
			todo(&l, input_path, l.where_firstchar, @FILE_LINE, 'global variable definition')
		}
	}

	os.write_file(config.output_path, output.str()) or {
		eprintln('error: ${err.msg()}: ${os.get_error_msg(err.code()).to_lower()}')
		return none
	}
}

fn main() {
	run() or { exit(1) }
}
