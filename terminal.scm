(define (terminal-command command)
  (display (string-append (list->string (list (integer->char #x1b))) command)))
(define (terminal-print text #!key (bg 'black) (fg 'white))
  (terminal-command (string-append "[" (case bg
					 ((black) "40") ((red)     "41")
					 ((green) "42") ((yellow)  "43")
					 ((blue)  "44") ((magenta) "45")
					 ((cyan)  "46") ((white)   "47"))
				   ";" (case fg
					 ((black) "30") ((red)     "31")
					 ((green) "32") ((yellow)  "33")
					 ((blue)  "34") ((magenta) "35")
					 ((cyan)  "36") ((white)   "37"))
				   "m"))
  (display text) ;; TODO dim doesn't seem to work, try the other effects (bold, underline, etc) maybe it's just my xterm that is badly configured
  (terminal-command "[0m")) ; reset
(define (clear-line)      (terminal-command "[K"))
(define (clear-to-bottom) (terminal-command "[J"))
(define (cursor-home)     (terminal-command "[H"))
(define (cursor-position-set! x #!optional (y #f))
  (terminal-command (string-append "[" (number->string x)
				   (if y
				       (string-append ";" (number->string y))
				       "")
				   "H")))

(define (cursor-notification-head) (cursor-position-set! 2))
(define (display-notification . s)
  (terminal-command (string-append "[" (number->string 60) "C"))
  (clear-line)
  (display (apply string-append s)))
