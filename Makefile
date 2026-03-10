.PHONY: load test check traceability clean

SBCL := sbcl --noinform --non-interactive
SBCL_LOAD := $(SBCL) \
	--eval '(require :asdf)' \
	--eval '(push (truename ".") asdf:*central-registry*)'

load:
	$(SBCL_LOAD) \
		--eval '(asdf:load-system "nilclaw")' \
		--eval '(format t "~%LOAD: OK~%")'

test:
	$(SBCL_LOAD) \
		--eval '(asdf:load-system "nilclaw/tests")' \
		--eval '(let ((results (fiveam:run (quote nilclaw/tests::nilclaw-suite)))) (fiveam:explain! results) (unless (fiveam:results-status results) (uiop:quit 1)))'

check: load test traceability

traceability:
	bash scripts/validate-traceability.sh

clean:
	find . -name '*.fasl' -delete
