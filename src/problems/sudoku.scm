;;; problems/sudoku.scm --- Sudoku solver implementations

(define-module (problems sudoku)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 format)
  #:use-module (core constraint-engine)
  #:use-module (z3 interface)
  #:export (sudoku-csp
            sudoku-z3
            print-sudoku
            example-sudoku))

;; Example puzzle (0 represents empty cells)
(define example-sudoku
  '((5 3 0 0 7 0 0 0 0)
    (6 0 0 1 9 5 0 0 0)
    (0 9 8 0 0 0 0 6 0)
    (8 0 0 0 6 0 0 0 3)
    (4 0 0 8 0 3 0 0 1)
    (7 0 0 0 2 0 0 0 6)
    (0 6 0 0 0 0 2 8 0)
    (0 0 0 4 1 9 0 0 5)
    (0 0 0 0 8 0 0 7 9)))

;; Native CSP approach
(define (sudoku-csp puzzle)
  "Solve Sudoku using native constraint solver"
  (let* ((variables
          (apply append
                 (map (lambda (row)
                        (map (lambda (col)
                               (let ((value (list-ref (list-ref puzzle row) col)))
                                 (make-variable
                                  (string->symbol (format #f "cell-~a-~a" row col))
                                  (if (zero? value)
                                      (make-domain '(1 2 3 4 5 6 7 8 9))
                                      (make-domain (list value))))))
                              (iota 9)))
                      (iota 9))))
         (constraints
          (append
           ;; Row constraints
           (map (lambda (row)
                  (all-different-constraint
                   (map (lambda (col)
                          (list-ref variables (+ (* row 9) col)))
                        (iota 9))))
                (iota 9))
           ;; Column constraints
           (map (lambda (col)
                  (all-different-constraint
                   (map (lambda (row)
                          (list-ref variables (+ (* row 9) col)))
                        (iota 9))))
                (iota 9))
           ;; 3x3 box constraints
           (apply append
                  (map (lambda (box-row)
                         (map (lambda (box-col)
                                (all-different-constraint
                                 (apply append
                                        (map (lambda (r)
                                               (map (lambda (c)
                                                      (list-ref variables
                                                               (+ (* (+ (* box-row 3) r) 9)
                                                                  (+ (* box-col 3) c))))
                                                    (iota 3)))
                                             (iota 3)))))
                              (iota 3)))
                       (iota 3))))))
    (solve-csp variables constraints)))

;; Z3 SMT solver approach
(define (sudoku-z3 puzzle)
  "Solve Sudoku using Z3 SMT solver"
  (let* ((cell-vars
          (apply append
                 (map (lambda (row)
                        (map (lambda (col)
                               (format #f "x~a~a" row col))
                             (iota 9)))
                      (iota 9))))
         (smt-code
          (string-append
           ;; Declare variables
           (string-join
            (map (lambda (var)
                   (make-smt-var var "Int"))
                 cell-vars)
            "\n")
           "\n"
           ;; Domain constraints (1 <= cell <= 9)
           (string-join
            (map (lambda (var)
                   (string-append
                    (smt-assert (format #f "(>= ~a 1)" var))
                    "\n"
                    (smt-assert (format #f "(<= ~a 9)" var))))
                 cell-vars)
            "\n")
           "\n"
           ;; Initial values
           (string-join
            (apply append
                   (map (lambda (row)
                          (map (lambda (col)
                                 (let ((value (list-ref (list-ref puzzle row) col)))
                                   (if (not (zero? value))
                                       (smt-assert
                                        (format #f "(= x~a~a ~a)" row col value))
                                       "")))
                               (iota 9)))
                        (iota 9)))
            "\n")
           "\n"
           ;; Row constraints
           (string-join
            (map (lambda (row)
                   (smt-assert
                    (format #f "(distinct ~a)"
                            (string-join
                             (map (lambda (col)
                                    (format #f "x~a~a" row col))
                                  (iota 9))
                             " "))))
                 (iota 9))
            "\n")
           "\n"
           ;; Column constraints
           (string-join
            (map (lambda (col)
                   (smt-assert
                    (format #f "(distinct ~a)"
                            (string-join
                             (map (lambda (row)
                                    (format #f "x~a~a" row col))
                                  (iota 9))
                             " "))))
                 (iota 9))
            "\n")
           "\n"
           ;; Box constraints
           (string-join
            (apply append
                   (map (lambda (box-row)
                          (map (lambda (box-col)
                                 (smt-assert
                                  (format #f "(distinct ~a)"
                                          (string-join
                                           (apply append
                                                  (map (lambda (r)
                                                         (map (lambda (c)
                                                                (format #f "x~a~a"
                                                                        (+ (* box-row 3) r)
                                                                        (+ (* box-col 3) c)))
                                                              (iota 3)))
                                                       (iota 3)))
                                           " "))))
                               (iota 3)))
                        (iota 3)))
            "\n")
           "\n(check-sat)\n(get-model)\n")))
    (let ((result (z3-solve smt-code)))
      (if (z3-sat? result)
          (parse-z3-model result)
          #f))))

;; Utility function to print Sudoku
(define (print-sudoku solution)
  "Print Sudoku solution"
  (if solution
      (begin
        (display "Sudoku Solution:\n")
        (for-each
         (lambda (row)
           (for-each
            (lambda (col)
              (let ((var-name (string->symbol (format #f "cell-~a-~a" row col))))
                (display (assoc-ref solution var-name))
                (display " ")
                (when (= col 2) (display "| "))
                (when (= col 5) (display "| "))))
            (iota 9))
           (newline)
           (when (or (= row 2) (= row 5))
             (display "------+-------+------\n")))
         (iota 9)))
      (display "No solution found\n")))