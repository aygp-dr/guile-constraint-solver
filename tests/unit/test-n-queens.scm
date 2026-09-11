(use-modules (srfi srfi-64)
             (srfi srfi-1)  ; for delete-duplicates, every, iota
             (problems n-queens))

(test-begin "n-queens")

(test-assert "4-Queens CSP solution exists"
  (n-queens-csp 4))

(test-equal "4-Queens CSP solution length"
  4
  (let ((solution (n-queens-csp 4)))
    (and solution (length solution))))

(test-assert "8-Queens CSP solution exists"
  (n-queens-csp 8))

;; Test that solution is valid (no attacks)
(test-assert "4-Queens solution is valid"
  (let ((solution (n-queens-csp 4)))
    (if solution
        (let ((positions (map cdr solution)))
          (and
           ;; All different columns
           (= (length positions) (length (delete-duplicates positions)))
           ;; No diagonal attacks
           (every (lambda (i)
                    (every (lambda (j)
                             (if (= i j)
                                 #t
                                 (not (= (abs (- i j))
                                        (abs (- (list-ref positions i)
                                               (list-ref positions j)))))))
                           (iota 4)))
                  (iota 4))))
        #f)))

(define failures (test-runner-fail-count (test-runner-current)))
(test-end "n-queens")
(exit (zero? failures))