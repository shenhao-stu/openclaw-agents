SHELL := /usr/bin/env bash

.PHONY: test test-shell

test: test-shell

test-shell:
	bash ./scripts/tests/test_setup_and_dispatch.sh
