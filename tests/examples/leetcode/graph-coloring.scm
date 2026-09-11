#!/usr/bin/env guile
!#

;;; leetcode/graph-coloring.scm --- Graph coloring constraint problem

(add-to-load-path (dirname (dirname (dirname (dirname (current-filename))))))

(use-modules (core constraint-engine)
             (z3 interface)
             (srfi srfi-1)
             (ice-9 format))

;; Graph representation: list of edges
(define example-graph
  '((0 . 1) (0 . 2) (1 . 2) (1 . 3) (2 . 3) (2 . 4) (3 . 4)))

(define (graph-coloring-csp graph num-vertices num-colors)
  "Solve graph coloring using native CSP solver"
  (let* ((vertices
          (map (lambda (i)
                 (make-variable
                  (string->symbol (format #f "v~a" i))
                  (make-domain (iota num-colors))))
               (iota num-vertices)))
         (constraints
          (map (lambda (edge)
                 (let ((u (car edge))
                       (v (cdr edge)))
                   (make-constraint
                    (list (list-ref vertices u)
                          (list-ref vertices v))
                    (lambda (color-u color-v)
                      (not (= color-u color-v))))))
               graph)))
    (solve-csp vertices constraints)))

(define (graph-coloring-z3 graph num-vertices num-colors)
  "Solve graph coloring using Z3 SMT solver"
  (let* ((vertex-vars
          (map (lambda (i)
                 (format #f "v~a" i))
               (iota num-vertices)))
         (smt-code
          (string-append
           ;; Declare variables
           (string-join
            (map (lambda (var)
                   (make-smt-var var "Int"))
                 vertex-vars)
            "\n")
           "\n"
           ;; Domain constraints (0 <= color < num-colors)
           (string-join
            (map (lambda (var)
                   (string-append
                    (smt-assert (format #f "(>= ~a 0)" var))
                    "\n"
                    (smt-assert (format #f "(< ~a ~a)" var num-colors))))
                 vertex-vars)
            "\n")
           "\n"
           ;; Edge constraints (adjacent vertices have different colors)
           (string-join
            (map (lambda (edge)
                   (let ((u (car edge))
                         (v (cdr edge)))
                     (smt-assert
                      (format #f "(not (= ~a ~a))"
                              (list-ref vertex-vars u)
                              (list-ref vertex-vars v)))))
                 graph)
            "\n")
           "\n(check-sat)\n(get-model)\n")))
    (let ((result (z3-solve smt-code)))
      (if (z3-sat? result)
          (parse-z3-model result)
          #f))))

(define (print-graph-coloring solution graph num-vertices)
  "Print graph coloring solution"
  (if solution
      (begin
        (display "Graph Coloring Solution:\n")
        (for-each
         (lambda (i)
           (let ((var-name (string->symbol (format #f "v~a" i))))
             (format #t "Vertex ~a: Color ~a\n"
                     i (assoc-ref solution var-name))))
         (iota num-vertices))
        (display "\nEdges (showing colors are different):\n")
        (for-each
         (lambda (edge)
           (let ((u (car edge))
                 (v (cdr edge)))
             (let ((color-u (assoc-ref solution (string->symbol (format #f "v~a" u))))
                   (color-v (assoc-ref solution (string->symbol (format #f "v~a" v)))))
               (format #t "Edge (~a,~a): Colors (~a,~a) ✓\n"
                       u v color-u color-v))))
         graph))
      (display "No solution found\n")))

(define (main)
  (display "=== Graph Coloring Problem ===\n")
  (display "Graph edges: ")
  (display example-graph)
  (newline)
  (display "Trying to color with 3 colors...\n\n")

  ;; Try CSP approach
  (display "CSP Solution:\n")
  (let ((solution (graph-coloring-csp example-graph 5 3)))
    (print-graph-coloring solution example-graph 5))

  (newline)

  ;; Try Z3 approach
  (display "Z3 Solution:\n")
  (let ((solution (graph-coloring-z3 example-graph 5 3)))
    (if solution
        (begin
          (display "Z3 model: ")
          (display solution)
          (newline))
        (display "No solution found\n"))))

(main)