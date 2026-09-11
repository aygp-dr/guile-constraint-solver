;;; z3/interface.scm --- Z3 SMT solver interface for Guile

(define-module (z3 interface)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (z3-solve
            z3-sat?
            parse-z3-model
            make-smt-var
            smt-assert
            smt-minimize
            smt-maximize))

(define (z3-solve smt-code)
  "Send SMT-LIB2 code to Z3 and return its output"
  ;; Z3 reads the script from a private temporary file.  Writing to `z3 -in'
  ;; over one OPEN_BOTH pipe deadlocks: Z3 waits for EOF on its stdin, which
  ;; stays open while we wait for its output.
  (catch #t
    (lambda ()
      (let* ((port (mkstemp! (string-append (or (getenv "TMPDIR") "/tmp")
                                            "/z3-input-XXXXXX")))
             (temp-file (port-filename port)))
        (dynamic-wind
          (lambda () #f)
          (lambda ()
            (display smt-code port)
            (close-port port)
            (let* ((pipe (open-pipe* OPEN_READ "z3" "-smt2" temp-file))
                   (result (get-string-all pipe)))
              (close-pipe pipe)
              result))
          (lambda ()
            (when (file-exists? temp-file)
              (delete-file temp-file))))))
    (lambda (key . args)
      (format #t "Error in z3-solve: ~a ~a\n" key args)
      "unsat")))

(define (z3-sat? output)
  "True when Z3's first reply is sat (not unsat or unknown)"
  (let ((status (find (lambda (line) (not (string-null? line)))
                      (map string-trim-both (string-split output #\newline)))))
    (and status (string=? status "sat"))))

(define (smt-value value)
  "Convert a Z3 model value to Scheme"
  (match value
    ('true #t)
    ('false #f)
    (('- (? number? n)) (- n))
    (_ value)))

(define (model-entries entries)
  (filter-map (match-lambda
                (('define-fun name () _ value) (cons name (smt-value value)))
                (_ #f))
              entries))

(define (parse-z3-model output)
  "Parse Z3 model output into an alist"
  ;; Z3 prints each define-fun over several lines, and older releases wrap
  ;; the model in (model ...), so read s-expressions rather than lines.
  (let ((port (open-input-string output)))
    (let loop ((form (read port)))
      (match form
        ((? eof-object?) '())
        (('model . entries) (model-entries entries))
        (((? pair?) ...) (model-entries form))
        (_ (loop (read port)))))))

(define (make-smt-var name type)
  "Generate SMT variable declaration"
  (format #f "(declare-const ~a ~a)" name type))

(define (smt-assert expr)
  "Generate SMT assertion"
  (format #f "(assert ~a)" expr))

(define (smt-minimize expr)
  "Generate SMT minimize objective"
  (format #f "(minimize ~a)" expr))

(define (smt-maximize expr)
  "Generate SMT maximize objective"
  (format #f "(maximize ~a)" expr))
