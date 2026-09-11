;;; problems/n-queens.scm --- N-Queens problem implementations

(define-module (problems n-queens)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (core constraint-engine)
  #:use-module (z3 interface)
  #:export (n-queens-csp
            n-queens-z3
            print-chessboard))

;; Native CSP approach
(define (n-queens-csp n)
  "Solve N-Queens using native constraint solver"
  (let* ((queens
          (map (lambda (i)
                 (make-variable
                  (string->symbol (format #f "queen-~a" i))
                  (make-domain (iota n))))
               (iota n)))
         (constraints
          (append
           ;; All different constraint (no two queens in same column)
           (list (all-different-constraint queens))
           ;; Diagonal constraints
           (apply append
                  (map (lambda (i)
                         (map (lambda (j)
                                (if (not (= i j))
                                    (make-constraint
                                     (list (list-ref queens i)
                                           (list-ref queens j))
                                     (lambda (qi qj)
                                       (not (= (abs (- i j))
                                              (abs (- qi qj))))))
                                    #f))
                              (iota n)))
                       (iota n))))))
    (solve-csp queens (filter identity constraints))))

;; Z3 SMT solver approach
(define (n-queens-z3 n)
  "Solve N-Queens using Z3 SMT solver"
  (let* ((queen-vars (map (lambda (i)
                           (format #f "q~a" i))
                         (iota n)))
         (smt-code
          (string-append
           ;; Declare variables
           (string-join
            (map (lambda (var)
                   (make-smt-var var "Int"))
                 queen-vars)
            "\n")
           "\n"
           ;; Domain constraints (0 <= qi < n)
           (string-join
            (map (lambda (var)
                   (string-append
                    (smt-assert (format #f "(>= ~a 0)" var))
                    "\n"
                    (smt-assert (format #f "(< ~a ~a)" var n))))
                 queen-vars)
            "\n")
           "\n"
           ;; All different constraint
           (smt-assert
            (format #f "(distinct ~a)"
                    (string-join queen-vars " ")))
           "\n"
           ;; Diagonal constraints
           (string-join
            (apply append
                   (map (lambda (i)
                          (map (lambda (j)
                                 (if (not (= i j))
                                     (smt-assert
                                      (format #f "(not (= (abs (- ~a ~a)) (abs (- ~a ~a))))"
                                              i j
                                              (list-ref queen-vars i)
                                              (list-ref queen-vars j)))
                                     ""))
                               (iota n)))
                        (iota n)))
            "\n")
           "\n(check-sat)\n(get-model)\n")))
    (let ((result (z3-solve smt-code)))
      (if (z3-sat? result)
          (parse-z3-model result)
          #f))))

;; Utility function to print chessboard
(define (print-chessboard solution n)
  "Print N-Queens solution as chessboard"
  (if solution
      (begin
        (display "Solution:\n")
        (let ((positions (if (list? (car solution))
                            (map cdr solution)  ; CSP format
                            (map cdr solution)))) ; Z3 format
          (for-each
           (lambda (row)
             (for-each
              (lambda (col)
                (if (= col (list-ref positions row))
                    (display "Q ")
                    (display ". ")))
              (iota n))
             (newline))
           (iota n))))
      (display "No solution found\n")))