SHELL := /bin/sh

.PHONY: all bootstrap lint test check synth-primer25k clean

all: check

bootstrap:
	./scripts/fetch_upstream.sh

lint: bootstrap
	./scripts/lint.sh

test: bootstrap
	./scripts/sim.sh

check: lint test

synth-primer25k: bootstrap
	./scripts/synth_primer25k.sh

clean:
	rm -rf build
