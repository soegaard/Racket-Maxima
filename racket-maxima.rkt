#lang at-exp racket
(require racket/tcp racket/gui/base
         (planet jaymccarthy/slideshow-latex/latex2bitmap))

;;;
;;; Maxima in Racket
;;;

;; This module starts an external Maxima process.
;; The function send will send a command to Maxima.
;; The function receive will get the output from Maxima as a list of strings.
;; The various send-* and receive-* functions sends and receives to and from Maxima.
;; The various read-* and display-* functions reads and displays to Racket (DrRacket).


;;; Configuration: Change maxima, latex and dvipng paths here.
(define PORT 8087)
(define MAXIMA-PATH "/Applications/Maxima.app/Contents/Resources/maxima.sh")

(define latex-enabled? #t) ; set to #f to disable latex rendering
(latex-path "/usr/texbin/latex")
(dvipng-path "/usr/texbin/dvipng")
(latex-debug? #f)  ; if #t prints errors from LaTeX.

;;; Parameters

(define out (make-parameter #f)) ; output port for sending 
(define in  (make-parameter #f)) ; input port for receiving

;;; Sending

(define (send str)
  (sync (out))
  (display str (out))
  (flush-output (out)))

(define (send-command str)
  (send str))

;; Receiving

(define (receive-line)
  (read-line (in)))

(define (receive-welcome-message)
  ; Due to the flag --very-quiet the welcome is 
  ; a single line containg the pid.
  (list (receive-line)))

(define (maybe-receive-line)
  (if (sync/timeout 0 (in))
      (receive-line)
      #f))
  
(define (receive)
  (let ([first-line (receive-line)])
    (let loop ([lines (list first-line)])
      (let ([line (maybe-receive-line)])
        (if line
            (loop (cons line lines))
            (reverse lines))))))

(define (receive-whitespace)
  (let ([c (read-char (in))])
    (when (not (char-whitespace? c))
      (error 'read-whitespace "expected to receive whitespace " c))))

;; String utilities

(define (blank-line? line)
  (andmap char-whitespace? (string->list line)))

(define (labeled-line? line)
  (regexp-match #rx"^(\\(.+\\)) (.*)$" line))

(define (remove-$$ str)
  (second (regexp-match #px"^\\$\\$(.*)\\$\\$" str)))

(define (string-begins-with-$$? str)
  (regexp-match #rx"^\\$\\$.*$" str))

(define (string-ends-with-$$? str)
  (regexp-match #rx"^.*\\$\\$$" str))

(define (maybe-add-$$ str)
  (string-append 
   (if (string-begins-with-$$? str)
       "" "$$")
   str
   (if (string-ends-with-$$? str)
       "" "$$")))

(define (string-ref-last str)
  (if (string=? "" str)
      #f
      (string-ref str (sub1 (string-length str)))))

;; List utilies

(define (remove-last xs)
  (if (empty? xs) xs (drop-right xs 1)))

;; Displaying

(define (display-line datum)
  (display datum)
  (newline))

(define (display-prompt prompt)
  (display prompt)
  (display " "))

(define (display-output lines)
  (unless (empty? lines)
    (display-lines
     (if (and latex-enabled? (string-begins-with-$$? (first lines)))
         (list (latex-lines (remove-last lines)))
         lines))))

(define (latex-lines lines)
  (latex (string-append* lines)))

(define (latex str)
  (parameterize ([latex-preamble "\\usepackage{breqn}"]
                 [latex-dpi 90])                                 
    (make-object image-snip%
      (latex->bitmap 
       @string-append{\begin{dmath*}[style={\huge}]@str \end{dmath*}}))))


;; Reading

(define (read-command)
  (let loop ([lines '()])
    (let ([line (read-line)])
      (if (memv (string-ref-last line) '(#\$ #\;))
          (string-append* (reverse (cons line lines)))
          (loop (cons line lines))))))

;; REPL
  
(define (read-send-receive-loop)
  (display-prompt ">")
  (send-command (read-command))
  (display-output (receive))
  (newline)
  (read-send-receive-loop))


;; Start Maxima and REPL

(let ([listener (tcp-listen PORT 3 #t)])
  (match-let
      ([(list pin pout pid perr status)
        (process* MAXIMA-PATH "--very-quiet" "-s" (format "~a" PORT))])
    (let-values ([(lin lout) (tcp-accept listener)])
      (parameterize ([in lin] [out pout])
        (receive-welcome-message)
        (display "Enter a Maxima command. Terminate a command with either ; or $ .\n")
        (read-send-receive-loop)))))
