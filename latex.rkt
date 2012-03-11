#reader scribble/reader
#lang racket
(require racket/system racket/gui/base)
(provide latex)

(define str string-append)

(define TEMPLATE
  @str{\documentclass[a0,landscape]{article}
       \usepackage[mathletters]{ucs}
       \usepackage[utf8x]{inputenc}
       \usepackage{amsmath}
       \pagestyle{empty}
       \usepackage{breqn}
       \begin{document}
       \hsize=150mm
       \begin{dmath*}[style={\huge}]
       ~a       
       \end{dmath*}
       \end{document}})

(define COMMANDS
  @str{/usr/texbin/pdflatex x.tex
       /opt/local/bin/convert -density 96x96 x.pdf -trim +repage x.png})

(define (latex . strs)
  (define latex (make-temporary-file "latex~a" 'directory))
  (define (run)
    (parameterize ([current-directory latex]
                   [current-input-port (open-input-bytes #"")]
                   [current-output-port (open-output-string)])
      (call-with-output-file* "x.tex" #:exists 'truncate
        (lambda (o) (fprintf o TEMPLATE (string-append* strs))))
      (unless (system (regexp-replace #rx"\n+" COMMANDS " \\&\\& "))
        (display (get-output-string (current-output-port))
                 (current-error-port))
        (error 'latex
               "commands did not run successfully, see above output"))
      (make-object image-snip% "x.png")))
  (define (cleanup) (delete-directory/files latex))
  ; (display-lines (list latex))
  (dynamic-wind void run cleanup))

;; Examples
;@latex{\sum_{i=0}^{\infty}\lambda_i}
;(let ([self @str{\lambda x . x x}])
;  @latex{(@self) (@self)})

;;; An example to test breaking lines with various page width
;@latex{
;x^{20}+20\,x^{19}+190\,x^{18}+1140\,x^{17}+4845\,x^{16}+15504\,x^{
; 15}+38760\,x^{14}+77520\,x^{13}+125970\,x^{12}+167960\,x^{11}+184756
; \,x^{10}+167960\,x^9+125970\,x^8+77520\,x^7+38760\,x^6+15504\,x^5+
; 4845\,x^4+1140\,x^3+190\,x^2+20\,x+1}
