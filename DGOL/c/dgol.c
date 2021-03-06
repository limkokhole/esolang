#include <stdio.h>
#include <stdlib.h>

#include "ast.h"
#include "dgol_libs.h"
#include "interpret.h"
#include "mymalloc.h"
#include "parse.h"
#include "resolver.h"

int main(int argc, char **argv)
{
	struct ast_module *ast_modules = 0;
	for (int i = argc-1; i >= 1; i--) {
		FILE *file = fopen(argv[i], "r");
		if (!file) {
			fprintf(stderr, "ERROR OPENING FILE %s\n", argv[i]);
			exit(1);
		}
		struct ast_module *ast_module = parse(file, argv[i]);
		fclose(file);
		ast_module->next_ast_module = ast_modules;
		ast_modules = ast_module;
	}

	struct dgol_lib *libs = dgol_lib();

	struct program *program = resolve(ast_modules, libs);

	dgol_lib_free(libs);
	parse_free_ast_modules(ast_modules);

	interpret(program);

	resolver_free_program(program);
	mymalloc_done();

	return 0;
}
