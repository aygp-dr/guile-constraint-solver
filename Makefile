.PHONY: all setup test examples clean

all: setup

setup:
	sh scripts/create-structure.sh
	sh scripts/install-deps.sh

test:
	guile -L . tests/unit/test-change-making.scm

examples:
	./examples/run-examples.scm

clean:
	find . -name "*.go" -delete
	find . -name "*~" -delete

tangle:
	emacs --batch -l org --eval "(org-babel-tangle-file \"setup.org\")"
