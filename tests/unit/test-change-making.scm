(use-modules (srfi srfi-64)
             (problems change-making))

(define (z3-counts model coins)
  "Coin counts from a Z3 model, in the order of COINS"
  (map (lambda (i)
         (or (assq-ref model (string->symbol (format #f "c~a" i))) 0))
       (iota (length coins))))

(test-begin "change-making")

(test-equal "DP solution for article example"
  4
  (length (make-change-dp 37 '(10 9 1))))

(test-equal "DP solution for simple case"
  2
  (length (make-change-dp 6 '(1 3 4))))

(test-equal "Z3 finds the 4-coin optimum"
  '(4 37)
  (let ((counts (z3-counts (make-change-z3 37 '(10 9 1)) '(10 9 1))))
    (list (apply + counts) (apply + (map * counts '(10 9 1))))))

(test-equal "Z3 reports no solution when change is impossible"
  #f
  (make-change-z3 3 '(2)))

(define failures (test-runner-fail-count (test-runner-current)))
(test-end "change-making")
(exit (zero? failures))
