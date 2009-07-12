;; needed in the included files
(include "class.scm") ; CLOS-like object system ;; TODO sucks that I can't put it in ~~/lib
(define-generic print) ; used for objects, cells, etc. ;; TODO receive bg and fg color ? or visibility ? as optional arguments, if methods can have them ?
(define-method (print o) #\space)

(include "utilities.scm") ;; TODO have a makefile, and separate compilation
(include "grid.scm")
(include "cell.scm")
(include "objects.scm")
(include "character.scm")
(include "player.scm")
(include "behavior.scm")
(include "monsters.scm")
(include "treasure.scm")
(include "dungeon.scm")
(include "visibility.scm")
(include "terminal.scm")
(include "input.scm")
(include "scheduler.scm")
(include "help.scm")

(define debug #f)

(random-source-randomize! default-random-source)
(tty-mode-set! (current-input-port) #t #t #t #f 0)
(shell-command "setterm -cursor off")
;; strangely, clear-to-bottom does not clear the bottom of the screen as it
;; should
(for-each (lambda (dummy) (display "\n")) (iota 50))

;; list of pairs (name . score), sorted by descending order of score
(define hall-of-fame
  (let ((hall (read-all (open-file (list path:   "hall-of-fame"
					 create: 'maybe)))))
    (if (null? hall)
	'()
	(car hall))))
(define (update-hall-of-fame name score level floor)
  (let* ((l   (sort-list (cons (list name score level floor) hall-of-fame)
			 (lambda (x y) (> (cadr x) (cadr y))))) ;; TODO if same score, sort with the other factors
	 (new (if (> (length l) 10) ; we keep the 10 best
		  (remove-at-index l 10)
		  l)))
    (set! hall-of-fame new)
    (with-output-to-file "hall-of-fame"
      (lambda () (display new)))
    new))


(define (game)
  (reschedule player)
  (let loop ()
    (for-each turn (find-next-active))
    (set! turn-no (+ turn-no 1))
    (loop)))

(define n-levels 3) ;; TODO change
(define player #f) ; needed for level-generation
(set! player (new-player (getenv "LOGNAME")))

(define (quit)
  (display "\nHall of fame:\n\n") ;; TODO have in a function
  (let* ((name         (string->symbol (player-name player)))
	 (xp           (player-experience player))
	 (level        (player-level player))
	 (floor-no     (character-floor-no player))
	 (current-game (list name xp level floor-no)))
    (let loop ((hall (update-hall-of-fame name xp level floor-no))
	       (highlight? #t))
      (if (not (null? hall))
	  (let ((head (car hall)))
	    (terminal-print
	     (string-append (symbol->string (car    head))
			    ":\t" ;; TODO alignment will be messed up anyways
			    (number->string (cadr   head))
			    "\tlevel "
			    (number->string (caddr  head))
			    "\tfloor "
			    (number->string (cadddr head))
			    "\n")
	     bg: (if (and highlight? (equal? (car hall) current-game))
		     'white
		     'black)
	     fg: (if (and highlight? (equal? (car hall) current-game))
		     'black
		     'white))
	    (loop (cdr hall)
		  (and highlight? (not (equal? (car hall) current-game))))))))
  (display "\n")
  ;; restore tty
  (tty-mode-set! (current-input-port) #t #t #f #f 0)
  (shell-command "setterm -cursor on")
  (exit))

(if (not debug) (game))
