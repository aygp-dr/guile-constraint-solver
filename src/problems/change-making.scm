;;; problems/change-making.scm --- Coin change problem implementations

(define-module (problems change-making)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (z3 interface)
  #:use-module (core constraint-engine)
  #:export (make-change-dp
            make-change-z3
            make-change-csp))

;; Dynamic programming approach
(define (make-change-dp total coins)
  "Find minimum coins to make change for total using dynamic programming"
  (let ((dp (make-vector (+ total 1) +inf.0)))
    (vector-set! dp 0 0)
    
    (do ((amount 1 (+ amount 1)))
        ((> amount total))
      (for-each
       (lambda (coin)
         (when (<= coin amount)
           (vector-set! dp amount
                        (min (vector-ref dp amount)
                             (+ 1 (vector-ref dp (- amount coin)))))))
       coins))
    
    ;; Reconstruct solution
    (if (= (vector-ref dp total) +inf.0)
        #f
        (let loop ((amount total)
                   (solution '()))
          (if (zero? amount)
              solution
              (let ((coin (find (lambda (c)
                                  (and (<= c amount)
                                       (= (vector-ref dp amount)
                                          (+ 1 (vector-ref dp (- amount c))))))
                                coins)))
                (loop (- amount coin)
                      (cons coin solution))))))))

;; Z3 SMT solver approach
(define (make-change-z3 total coins)
  "Solve change making using Z3 SMT solver"
  (let* ((coin-vars (map (lambda (c i)
                          (format #f "c~a" i))
                        coins
                        (iota (length coins))))
         (smt-code
          (string-append
           ;; Declare variables
           (string-join
            (map (lambda (var)
                   (make-smt-var var "Int"))
                 coin-vars)
            "\n")
           "\n"
           ;; Non-negative constraints
           (string-join
            (map (lambda (var)
                   (smt-assert (format #f "(>= ~a 0)" var)))
                 coin-vars)
            "\n")
           "\n"
           ;; Sum constraint
           (smt-assert
            (format #f "(= (+ ~a) ~a)"
                    (string-join
                     (map (lambda (var coin)
                            (format #f "(* ~a ~a)" var coin))
                          coin-vars coins)
                     " ")
                    total))
           "\n"
           ;; Objective
           (smt-minimize (format #f "(+ ~a)" (string-join coin-vars " ")))
           "\n(check-sat)\n(get-model)\n")))
    (let ((result (z3-solve smt-code)))
      (if (z3-sat? result)
          (parse-z3-model result)
          #f))))

;; Native CSP approach
(define (make-change-csp total coins max-coins)
  "Solve using native constraint solver"
  
  (let* ((coin-vars
          (map (lambda (coin i)
                 (make-variable
                  (string->symbol (format #f "coin-~a" i))
                  (make-domain (iota (+ (quotient total coin) 1)))))
               coins (iota (length coins))))
         (constraints
          (list
           ;; Sum constraint
           (make-constraint coin-vars
             (lambda counts
               (= (apply + (map * counts coins)) total)))
           ;; Minimize total coins
           (make-constraint coin-vars
             (lambda counts
               (<= (apply + counts) max-coins))))))
    
    ;; Try increasing max-coins until solution found
    (let loop ((max max-coins))
      (or (solve-csp coin-vars constraints)
          (loop (+ max 1))))))
