SHELL := /bin/sh

.PHONY: all bootstrap lint test test-m2 model-test check wave wave-open export-yc validate-m1 validate-m2 synth-primer25k clean

all: check

bootstrap:
	./scripts/fetch_upstream.sh

lint: bootstrap
	./scripts/lint.sh

test: bootstrap
	./scripts/sim.sh

test-m2: bootstrap
	./scripts/sim_m2.sh

model-test:
	python3 scripts/model_test.py

check: lint test test-m2 model-test

wave: bootstrap
	./scripts/wave.sh

wave-open: bootstrap
	./scripts/wave.sh --open

export-yc: bootstrap
	./scripts/export_yc.sh

validate-m1: export-yc
	python3 scripts/render_composite.py \
		--input build/vectors/yc_out.csv \
		--output-dir build/m1

validate-m2: test-m2

synth-primer25k: bootstrap
	./scripts/synth_primer25k.sh

clean:
	rm -rf build
