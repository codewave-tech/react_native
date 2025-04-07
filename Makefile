CLI_TOOL_NAME = react_native

build:
	@dart compile exe bin/${CLI_TOOL_NAME}.dart -o ./bin/${CLI_TOOL_NAME}

run:
	@dart run

run-exec: build
	@./bin/${CLI_TOOL_NAME}

