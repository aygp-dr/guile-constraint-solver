(use-modules (srfi srfi-64)
             (z3 interface))

(test-begin "z3-interface")

(test-assert "sat is sat"
  (z3-sat? "sat\n((define-fun x () Int 1))\n"))

(test-assert "unsat is not sat"
  (not (z3-sat? "unsat\n(error \"line 5 column 10: model is not available\")\n")))

(test-assert "unknown is not sat"
  (not (z3-sat? "unknown\n")))

(test-assert "no output is not sat"
  (not (z3-sat? "")))

(test-equal "multi-line model"
  '((c0 . 1) (c1 . 3) (b . #t) (n . -2))
  (parse-z3-model
   "sat\n(\n  (define-fun c0 () Int\n    1)\n  (define-fun c1 () Int\n    3)\n  (define-fun b () Bool\n    true)\n  (define-fun n () Int\n    (- 2))\n)\n"))

(test-equal "legacy (model ...) wrapper"
  '((x . 5))
  (parse-z3-model "sat\n(model\n  (define-fun x () Int 5)\n)\n"))

(test-equal "no model after unsat"
  '()
  (parse-z3-model "unsat\n(error \"line 5 column 10: model is not available\")\n"))

(test-equal "z3-solve round trip"
  '(#t 1 3)
  (let* ((out (z3-solve "(declare-const a Int)\n(declare-const b Int)\n(assert (= a 1))\n(assert (= b 3))\n(check-sat)\n(get-model)\n"))
         (model (parse-z3-model out)))
    (list (z3-sat? out) (assq-ref model 'a) (assq-ref model 'b))))

(define failures (test-runner-fail-count (test-runner-current)))
(test-end "z3-interface")
(exit (zero? failures))
