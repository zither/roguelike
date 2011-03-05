#lang racket

(require "class.rkt" "utilities.rkt" "cell.rkt" "grid.rkt" "scheduler.rkt"
         "character.rkt" "objects.rkt" "items.rkt" "floor.rkt" "dungeon.rkt"
         "encounters.rkt" "treasure.rkt" "visibility.rkt" "common.rkt"
         "monsters.rkt" "terminal.rkt" "display.rkt"
         (only-in srfi/1 iota))
(provide (all-defined-out))

(define-class <player-character> (character)
  (slot: floors-before) ; pairs (map . view)
  (slot: current-floor)
  (slot: floors-after)

  (slot: experience)
    
  (slot: inventory)) ; list of objects
(define (new-player name) ;; TODO constructor ?
  (let ((player (make-player-character
                 name #f #f
                 ;; TODO have a way to select (and also display, maybe press r
                 ;;  for roster, c for character)
                 16 14 14 10 10 10 (make-hash) 0
                 1 '(10) ; hit dice
                 #f #f
                 1 #f 1 ; base and current attack bonus, nb attacks
                 6 ; speed, 6 seconds for a turn
                 (new-equipment #:main-hand (new-club))
                 '() #f '()
                 0 '())))
    (init-hp player #t) ; the player gets maxed out hp
    (place-player player (new-player-floor 0 1))
    player))
(define-method (show (p struct:player-character)) #\@)

(define-method (turn (p struct:player-character) reschedule?)
  (if (and (<= (character-hp player) 0)
	   (not (unbox god-mode?))) ; for debugging
      (begin (display "You die.\n")
	     (quit))
      (begin
	;; if we don't move, we can get multiple attacks (if we have more
	;; than one attack). these "attacks" can also be used to drink
	;; potions or anything else apart from moving. moving stops the
	;; sequence of attacks (so the last "attack" could be a move)
	;; TODO an interesting variant would be to move a certain amount of
        ;;  times, and then only be able to attack, and attack the right
        ;;  number of times, then start the cycle again. would help to display
        ;;  these numbers to the player
	;; TODO would be nice to have both a move action and an attack, but to
        ;;  be able to do a full attack only if we didn't move
	(let ((pos (character-pos player))
	      (bab (character-base-attack-bonus player))) ; to check if we moved
	  (let loop ((n            (character-nb-attacks player))
		     (attack-bonus bab))
	    (when (and (> n 0) (equal? (character-pos player) pos))
		(set-character-current-attack-bonus! player attack-bonus)
                ;; if we didn't move, we can keep attacking
                ;; TODO handle other full-turn actions
                (when (not (eq? (read-command) 'move))
                  (loop (- n 1) (- attack-bonus 5))))))
        ;; TODO call-next-method, especially with multiple attack handling
	(when reschedule? (reschedule player)))))

(define-struct player-floor
  (floor ; views are a grid of either visible, visited or unknown
   view)
  #:transparent)
(define (new-player-floor no player-level)
  (let ((floor (generate-floor no (< no (- n-levels 1)))))
    ;; add everything else on top
    (place-encounters floor player-level)
    (place-treasure   floor)
    (make-player-floor floor (init-visibility (floor-map floor)))))


(define (player-map   player)
  (floor-map (character-floor player)))
(define (player-view  player)
  (player-floor-view (player-character-current-floor player)))

(define (place-player
	 player player-floor
	 #:start-pos (start-pos (floor-stairs-up
                                 (player-floor-floor player-floor))))
  (let* ((floor (player-floor-floor player-floor))
	 (map   (floor-map floor)))
    (set-cell-occupant!                  (grid-ref map start-pos) player)
    (set-character-pos!                  player start-pos)
    (set-player-character-current-floor! player player-floor)
    (set-character-floor!                player floor)
    (reset-turn-no)
    (reset-turn-id)
    (reset-turn-queue)
    ;; no need to reschedule the player, since he will get rescheduled at the
    ;; end of his turn
    (for-each reschedule (floor-monsters floor))))


(define (show-state)
  (cursor-notification-head)
  (printf-notification "~a\n" (character-name player))
  (printf-notification "level ~a\n" (character-level player))
  (printf-notification "~a xp pts\n" (player-character-experience player))
  (printf-notification "")
  (when (altered-attr? player 'hp)
    (terminal-colors 'white 'black)) ;; TODO abstract that
  (display (character-hp player))
  (terminal-reset)
  (printf "/~a hp\n" (character-max-hp player))
  
  (printf-notification "AC: ")
  (when (altered-attr? player 'natural-ac)
    (terminal-colors 'white 'black))
  (display (get-armor-class player))
  (terminal-reset)
  (newline)
  
  (printf-notification "str: ")
  (when (altered-attr? player 'str)
    (terminal-colors 'white 'black))
  (display (character-str player))
  (terminal-reset)
  (display "	int: ")
  (when (altered-attr? player 'int)
    (terminal-colors 'white 'black))
  (display (character-int player))
  (terminal-reset)
  (newline)
  
  (printf-notification "dex: ")
  (when (altered-attr? player 'dex)
    (terminal-colors 'white 'black))
  (display (character-dex player))
  (terminal-reset)
  (display "	wis: ")
  (when (altered-attr? player 'wis)
    (terminal-colors 'white 'black))
  (display (character-wis player))
  (terminal-reset)
  (newline)
  
  (printf-notification "con: ")
  (when (altered-attr? player 'con)
    (terminal-colors 'white 'black))
  (display (character-con player))
  (terminal-reset)
  (display "	cha: ")
  (when (altered-attr? player 'cha)
    (terminal-colors 'white 'black))
  (display (character-cha player))
  (terminal-reset)
  (newline)
  
  (cursor-home)
  (clear-line)
  (printf "Floor ~a\n" (+ (floor-no (character-floor player)) 1))
  (show-grid (player-map player)
	     #:print-fun (visibility-show (player-view player)
                                          (player-map  player))))


(define (update-visibility)
  ;; TODO maybe show visible parts in dark yellow instead of white background?
  ;;  to simulate a lantern
  ;; set the fog of war
  (let ((view (player-view player))
	(pos  (character-pos player)))
    (grid-for-each (lambda (pos)
		     (when (eq? (grid-ref view pos) 'visible)
                       (grid-set! view pos 'visited)))
		   view)

    ;; field of vision using shadow casting (spiral path FOV)
    ;; see roguebasin.roguelikedevelopment.org/index.php?title=Spiral_Path_FOV
    (let* ((g     (player-map player))
	   (x     (point-x    pos))
	   (y     (point-y    pos)))
      (let loop ((queue (list pos)))
	(define (pass-light pos new)
	  ;; enqueue cells depending on the orientation of new from pos
	  (let* ((pos-x (point-x pos)) (pos-y (point-y pos))
		 (new-x (point-x new)) (new-y (point-y new))
		 (dirs  (four-directions new))
		 (north (list-ref dirs 0))
		 (south (list-ref dirs 1))
		 (west  (list-ref dirs 2))
		 (east  (list-ref dirs 3)))
	    (cond ((< new-x pos-x) ; somewhere north
		   (cond ((= new-y pos-y) (list east north west)) ; due north
			 ((< new-y pos-y) (list north west))      ; north-west
			 ((> new-y pos-y) (list east north))))    ; north-east
		  ((> new-x pos-x) ; somewhere south
		   (cond ((= new-y pos-y) (list west south east)) ; due south
			 ((< new-y pos-y) (list west south))      ; south-west
			 ((> new-y pos-y) (list south east))))    ; south-east
		  ((< new-y pos-y) (list north west south))       ; due west
		  ((> new-y pos-y) (list south east north))       ; due east
		  (else ; we are at the starting point
		   (list east north west south)))))
	(when (not (null? queue))
          (let ((new (car queue)))
            (when (and (inside-grid? view new)
                       (not (eq? (grid-ref view new)
                                 'visible)) ; already seen
                       ;; TODO have range in a variable, maybe a player trait
                       ;;  (elves see farther?)
                       (<= (distance pos new) 7) ; within range
                       ;; do we have line of sight ? helps restrict the
                       ;; visibility down to a reasonable level
                       ;; note: line of sight is not necessary to see walls,
                       ;; this gives better results
                       (or (opaque-cell? (grid-ref g new) #f)
                           (line-of-sight? g pos new)))
              (grid-set! view new 'visible) ; mark as lit
              (when (not (opaque-cell? (grid-ref g new) #f))
                (loop (append (cdr queue)
                              (pass-light pos new)))))
            (loop (cdr queue)))))

      ;; one last pass to solve the problem case of walls that are hard to
      ;; see, which gives ugly results
      ;; to solve the problem, any wall next to a visible square is visible
      (grid-for-each
       (lambda (pos)
	 (when (and (opaque-cell? (grid-ref g pos) #f)
                    (eq? (grid-ref view pos) 'unknown)
                    (ormap
                     (lambda (new)
                       (and (not (opaque-cell? (grid-ref-check g new) #f))
                            (eq? (grid-ref-check view new) 'visible)))
                     (eight-directions pos)))
           (grid-set! view pos 'visited)))
       view))))


;; commands
(define (invalid-command) (display "Invalid command.\n"))

(define (which-direction?)
  (when (not (eq? (read-char) #\[))
    (invalid-command))
  (case (read-char)
    ((#\A) 'up)
    ((#\B) 'down)
    ((#\C) 'right)
    ((#\D) 'left)
    (else  (invalid-command))))

(define (read-command)
  ;; TODO define all this inside a macro, so that a description can be
  ;;  included with the commands ? or keep 2 separate lists ? or just a
  ;;  lookup list of commands, functions, and doc ? yeah, probably that
  ;;  last one, BUT how to have entries for the movement arrows ?
  (update-visibility)
  (show-state)

  (let* ((pos   (copy-point (character-pos player)))
	 (grid  (floor-map (character-floor player)))
	 (x     (point-x pos))
	 (y     (point-y pos))
	 (char  (read-char)))

    (clear-to-bottom)

    ;; escape. bizarrely unrecognizable with case...
    (if (= (char->integer char) 27)
        ;; movement
        (begin (case (which-direction?)
                 ;; TODO abstract with other arrow reading code below
                 ((up)    (set-point-x! pos (- x 1)))
                 ((down)  (set-point-x! pos (+ x 1)))
                 ((right) (set-point-y! pos (+ y 1)))
                 ((left)  (set-point-y! pos (- y 1))))
               ;; tries to move to the new position
               ;; if it fails, stay where we were
               (move grid player pos)
               'move)
        (case char
          ;; inventory ;; TODO have all this generated by macros
          ((#\p) (pick-up pos) 'pick-up)
          ((#\d) (cmd-drop)    'cmp-drop)
          ((#\i) (inventory)   'inventory)
          ((#\e) (equip)       'equip)
          ((#\r) (take-off)    'take-off)
          ((#\D) (cmd-drink)   'cmd-drink)
          
          ((#\o) (cmd-open)     'cmd-open)
          ((#\c) (cmd-close)    'cmd-close)
          ((#\t) (climb-stairs) 'stairs)
          
          ((#\s) (shoot) 'shoot)
          
          ;; help
          ((#\?) (show-help)     'show-help)
          ((#\n) (info grid pos) 'info)
          ((#\l) (look grid pos) 'look)
          
          ;; debugging
          ((#\k) (kill)    'kill) ; insta-kill a monster
          ((#\:) (console) 'console)
          
          ((#\space) (display "Nothing happens.\n") 'noop)
          ((#\q)     (quit)                         'quit)
          (else      (invalid-command)              'invalid)))))
;; TODO have a README with all that...

(define (choose-direction)
  (if (= (char->integer (read-char)) 27) ; escape
      (case (which-direction?)
        ((up)    up)
        ((down)  down)
        ((left)  left)
        ((right) right))
      (begin (invalid-command)
             #f)))

(define (read-number n) ; read a number up to n, or q to cancel
  (let loop ((nb (read-char)))
    (cond ((eq? nb #\q)
	   #f) ; cancel
	  ((not (and (char>=? nb #\1)
		     (<= (- (char->integer nb) (char->integer #\0)) n)))
	   (loop (read-char)))
	  (else
	   (- (char->integer nb)
	      (char->integer #\0) 1)))))

(define (choice objects f null-message question feedback)
  (if (null? objects)
      (printf "~a\n" null-message)
      (begin   (cursor-home)
	       (clear-to-bottom)
               (printf "~a\nq: Cancel\n" question)
	       (for-each (lambda (o i)
                           (printf "~a: ~a\n" (+ i 1) (object-info o)))
			 objects
			 (iota (length objects)))
	       (let ((nb (read-number (length objects))))
		 (when nb
                   (let ((object (list-ref objects nb)))
                     (show-state)
                     (f object)
                     (printf "~a~a.\n" feedback (object-info object))))))))

(define (direction-command name f)
  (clear-to-bottom)
  (printf "~a in which direction? " name)
  (flush-output) ;; TODO may be necessary elsewhere
  (let ((dir (choose-direction))) ; evaluates to a function, or #f
    (when dir
      (let* ((grid (player-map player))
             (cell (grid-ref grid (dir (character-pos player)))))
        (f grid cell player)))))

;; console from which arbitrary expressions can be evaluated
(define (console)
  (system "stty cooked echo")
  (system "setterm -cursor on")
  (display ": ")
  (display (eval (read))) ;; TODO not sure this is going to work...
  (read-char)
  (system "setterm -cursor off")
  (system "stty raw -echo opost") ;; TODO abstract these somewhere
  )

;; for debugging
(define (reveal-map)
  (let ((view (player-view player)))
    (grid-for-each (lambda (p) (grid-set! view p 'visited))
		   view)))
(define (god-mode)
  (reveal-map)
  (set-box! god-mode? #t))


(define (quit)
  (display "\nHall of fame:\n\n") ;; TODO have in a function
  (let* ((name         (string->symbol (character-name player)))
	 (xp           (player-character-experience player))
	 (level        (character-level player))
	 (floor-no     (+ (floor-no (character-floor player)) 1))
	 (current-game (list name xp level floor-no))
         (filename     "hall-of-fame"))
    (define (update-hall-of-fame)
      ;; list of pairs (name . score), sorted by descending order of score
      (let* ((l   (sort (cons current-game
                              (if (file-exists? filename)
                                  (with-input-from-file filename read)
                                  '()))
                        ;; TODO if same score, sort with the other factors
                        > #:key cadr))
	     (new (take l (min (length l) 10)))); we keep the 10 best
	(display new (open-output-file filename #:exists 'replace))
	new))
    (let loop ((hall (update-hall-of-fame))
	       (highlight? #t))
      (when (not (null? hall))
        (let ((head (car hall)))
          (terminal-print
           (format "~a:\t~a\tlevel ~a\tfloor ~a\n"
                   (car head) (cadr head) (caddr head) (cadddr head))
           #:bg (if (and highlight? (equal? (car hall) current-game))
                    'white
                    'black)
           #:fg (if (and highlight? (equal? (car hall) current-game))
                    'black
                    'white))
          (loop (cdr hall)
                (and highlight? (not (equal? (car hall) current-game))))))))
  (newline)
  ;; restore tty
  (system "stty cooked echo")
  (system "setterm -cursor on")
  (exit))


(define (inventory)
  (cursor-home)
  (clear-to-bottom)
  (display "Equipment:\n")
  (for-each-equipped
   (lambda (obj where)
     (printf "~a~a\n" where (if obj (object-info obj) "")))
   (character-equipment player))
  (printf "\nAC: ~a\n" (get-armor-class player))
  (display "\nInventory:\n")
  (for-each (lambda (o) (printf "~a\n" (object-info o)))
	    (player-character-inventory player))
  (let loop ((c #f))
    (case c
      ((#\e) (equip))
      ((#\r) (take-off))
      ((#\d) (cmd-drop))
      ((#\q) #f)
      (else (display "\ne: Equip\nr: Take off\nd: Drop\nq: Cancel\n")
            (loop (read-char)))))
  (clear-to-bottom))
(define (pick-up pos) ;; TODO pos can be useful if we can pick up at a distance
  (let* ((cell    (grid-ref (player-map player) pos))
	 (objects (cell-objects cell)))
    (choice objects
	    (lambda (object)
	      (remove-object cell object)
	      (set-player-character-inventory!
               player (cons object (player-character-inventory player))))
	    "There is nothing to pick up." "Pick up what?" "Picked up ")))
(define (cmd-drop)
  (let ((cell    (grid-ref (player-map player) (character-pos player)))
	(objects (player-character-inventory player)))
    (choice objects
	    (lambda (object)
	      (set-player-character-inventory! player (remove object objects))
	      (add-object cell object))
	    "You have nothing to drop." "Drop what?" "Dropped ")))
(define (equip)
  (let ((e       (character-equipment player))
	(objects (filter (lambda (x) (equipable-object? x))
			 (player-character-inventory player))))
    (choice objects
	    (lambda (object)
              ;; TODO macro?
	      (let* ((place (cond ((weapon?     object) 'main-hand)
				  ((shield?     object) 'off-hand)
				  ((body-armor? object) 'torso)))
		     (old   ((case place
			       ((main-hand) equipment-main-hand)
			       ((off-hand)  equipment-off-hand)
			       ((torso)     equipment-torso))
			     e)))
		(define (back-in-inventory o)
                  (printf "Put ~a back in inventory.\n" (object-name o))
		  (set-player-character-inventory!
		   player (cons o (player-character-inventory player))))
		(set-player-character-inventory!
                 player (remove object objects))
		((case place
		   ((main-hand) set-equipment-main-hand!)
		   ((off-hand)  set-equipment-off-hand!)
		   ((torso)     set-equipment-torso!))
		 e object)
                ;; TODO generalize with all non-removable items
		(cond ((and old (not (off-hand-placeholder? old)))
		       (back-in-inventory old))
		      ((two-handed-weapon? old)
		       (set-equipment-off-hand! e #f)) ; remove the placeholder
		      ((off-hand-placeholder? old)
		       ;; we have to remove the two-handed weapon itself
		       (back-in-inventory (equipment-main-hand e))
		       (set-equipment-main-hand! e #f)))
		(when (two-handed-weapon? object)
                  (let ((old-off (equipment-off-hand e)))
                    (when (and old-off (not (off-hand-placeholder? old-off)))
                      (back-in-inventory old-off))
                    (set-equipment-off-hand! e (new-off-hand-placeholder))))))
	    "You have nothing to equip." "Equip what?" "Equipped ")))
(define (take-off)
  (let* ((e       (character-equipment player))
	 (objects (filter (lambda (obj) (and obj (removable? obj)))
			  (map car (equipment->list e)))))
    (choice objects
	    (lambda (object)
	      (cond ((weapon?     object)
		     (set-equipment-main-hand! e #f)
		     (when (two-handed-weapon? object)
                       ;; remove the placeholder
                       (set-equipment-off-hand! e #f)))
		    ((shield?     object)
		     (set-equipment-off-hand!  e #f))
		    ((body-armor? object)
		     (set-equipment-torso!     e #f)))
	      (set-player-character-inventory!
               player (cons object (player-character-inventory player))))
	    "You have nothing to take off." "Take off what?" "Took off ")))

(define (cmd-drink)
  (let* ((e       (character-equipment player))
	 (objects (player-character-inventory player))
	 (o       #f))
    (choice objects
	    (lambda (object)
	      (set! o object)
	      (set-player-character-inventory! player (remove object objects)))
	    "You have nothing to drink." "Drink what?" "Drank ")
    ;; necessary to display the messages in the right order
    (when o (drink o) (attacks-of-opportunity player))))

(define (climb-stairs)
  (let ((cell (grid-ref (player-map player) (character-pos player))))
    (let ((current      (player-character-current-floor player))
	  (before       (player-character-floors-before player))
	  (after        (player-character-floors-after  player)))
      (cond ((stairs-up? cell)
	     (cond ((not (null? before))
		    (let ((new (car before)))
		      (place-player
		       player new
		       #:start-pos (floor-stairs-down
                                    (player-floor-floor new)))
		      (set-player-character-floors-after!
                       player (cons current after))
		      (set-player-character-floors-before!
                       player (cdr before))))
		   (else (display "This would lead to the surface.\n"))))
	    ((stairs-down? cell)
	     (set-player-character-floors-before! player (cons current before))
	     (if (null? after)
		 ;; if we would generate the last floor, don't put stairs down
		 (place-player player
			       (new-player-floor
				(+ (floor-no (character-floor player))
				   1)
                                (character-level player)))
		 (begin (place-player             player (car after))
			(set-player-character-floors-after!
                         player (cdr after)))))
	    (else (display "There are no stairs here.\n"))))))

(define (cmd-open)  (direction-command "Open"  open))
(define (cmd-close) (direction-command "Close" close))

(define-method (attack (attacker struct:player-character) defender)
  (printf "~a attacks the ~a"
          (character-name attacker)
          (character-name defender))
  ;; TODO instead of check-if-hit, use call-next-method?
  (check-if-hit attacker defender))
(define-method (ranged-attack (attacker struct:player-character) defender)
  (printf "~a shoots at the ~a"
          (character-name attacker)
          (character-name defender))
  (check-if-hit attacker defender get-ranged-attack-bonus)
  (attacks-of-opportunity attacker))

(define (shoot)
  (let* ((grid    (player-map player))
	 (weapon  (equipment-main-hand (character-equipment player)))
	 (targets (filter (lambda (m)
			    (and (eq? (grid-ref (player-view player)
						(character-pos m))
				      'visible)
				 (clear-shot? grid
					      (character-pos player)
					      (character-pos m))))
			  (floor-monsters (character-floor player))))
	 (n       (length targets)))
    (cond
     ((not (ranged-weapon? weapon))
      (display "I can't shoot with that.\n"))
     ((null? targets)
      (display "There is nothing to shoot.\n"))
     (else
      (let ((grid (let ((grid (grid-copy grid)))
		    (for-each
		     (lambda (m n) ;; TODO like choice, won't scale over 10
		       (grid-set!
			grid
			(character-pos m)
			(new-display-cell
			 (string-ref (number->string (+ n 1)) 0))))
		     targets
		     (iota n))
		    grid)))
	;; show which monsters are which numbers
	(cursor-home) ;; TODO taken from show-state
	(clear-to-bottom)	  
	(cursor-notification-head)
	(for-each (lambda (m n)
		    (printf-notification "~a: ~a\n"
                                         (+ n 1) (character-name m)))
		  targets
		  (iota n))
        (newline)
	(printf-notification "q: Cancel\n")
	;; show the map with the target numbers
	(cursor-home)
        (printf "Floor ~a\n" (+ (floor-no (character-floor player)) 1))
	(show-grid grid
		   #:print-fun (visibility-show (player-view player)
                                                (player-map  player)))
	;; choose a target
	(let ((nb (read-number n)))
	  (when nb (ranged-attack player (list-ref targets nb)))))))))


(define-method (damage (attacker struct:player-character)
                       (defender struct:monster))
  (let ((dmg (max (get-damage attacker) 1))) ;; TODO could deal 0 damage ?
    ;; TODO copied from character.scm, the fallback method, call-next-method?
    ;;  (but would mess up with the .\n at the end)
    (printf " and deals ~a damage" dmg)
    (set-character-hp! defender (- (character-hp defender) dmg))
    (if (<= (character-hp defender) 0)
	(remove-monster defender)
	(display ".\n"))))

;; TODO not all that clean to have it here, but it's the only place where it
;;  would not lead to circular dependencies
;;  -> parameter?
;; removes a monster, usually when killed
(define (remove-monster monster)
  (printf ", which kills the ~a.\n" (character-name monster))
  (let* ((floor (character-floor monster))
	 (cell  (grid-ref (floor-map floor) (character-pos monster))))
    ;; drop equipment with a certain probability TODO TWEAK
    (for-each-equipped (lambda (obj where)
			 (when (and obj (removable? obj) (random-boolean 0.3))
                           (add-object cell obj)))
		       (character-equipment monster))
    ;; remove the monster
    (set-cell-occupant! cell #f)
    (set-floor-monsters! floor (remove monster (floor-monsters floor)))
    ;; give experience
    (let* ((challenge     (character-level monster))
	   (xp-same-level (* challenge 300))
	   (delta-level   (- challenge (character-level player))))
      (add-experience (if (= delta-level 0)
			  xp-same-level
			  (max 0
			       (ceiling (* xp-same-level
					   (+ 1 (* 1/3 delta-level))))))))))

(define (add-experience xp)
  (let ((total (+ (player-character-experience player) xp))
	(level (character-level player)))
    (set-player-character-experience! player total)
    (when (>= total (* 1000 (/ (* level (+ level 1)) 2)))
      ;; 1000, 3000, 6000, ...
      (level-up))))

(define (level-up) ;; TODO have attribute upgrades, etc
  (display "Level up!\n")
  (let* ((old-level (character-level player))
	 (new-level (+ old-level 1)))
    (set-character-level! player new-level)
    (let ((hd (character-hit-dice player)))
      (set-character-hit-dice! player (cons (car hd) hd))
      (init-hp player #t))
    (set-character-base-attack-bonus!
     player (+ (character-base-attack-bonus player) 1))
    (when (= (modulo old-level 5) 0) ; 6, 11, ...
      ;; add a new attack
      (set-character-nb-attacks! player (+ (character-nb-attacks player) 1)))))


(define (kill) ; insta-kill something, for debugging purposes
  (direction-command "Kill"
		     (lambda (grid cell player)
		       (cond ((cell-occupant cell)
			      => (lambda (occ)
                                   (printf "Killed the ~a\n"
                                           (character-name occ))
				   (remove-monster occ)))
			     (else (display
				    "There is nothing to kill there.\n"))))))

(define (show-help)
  ;; TODO maybe generate commands with a macro and have help text that can be
  ;;  displayed by help, everything would be automatic
  'TODO)

(define (info grid pos)
  ;; TODO show a message about the location, occupant first (unless player),
  ;;  objects then, finally terrain
    (let ((cell (grid-ref grid pos)))
      (cond ((let ((occ (cell-occupant cell)))
	       (and occ (not (player-character? occ)) occ))
	     => (lambda (occ) (display (character-name occ))))
;; 	    ((car (cell-objects cell))
;; 	     => (lambda (obj) (display (object-name obj))))
            ;; TODO broken. + add monsters
	    (else
	     (display "Nothing to see here.")))))
;; TODO describe the terrain, have a description for each type, ideally
;;  define with the type

(define (look grid pos)
  ;; TODO have a moveable cursor, and when enter is pressed, display the info
  ;;  of the location, pos is starting position of the cursor, if final cursor
  ;;  position is outside visibility, say I can't see there
  ;; TODO use the choose-direction command to control the cursor
  (system "setterm -cursor on")
  ;; TODO maybe just be able to look at immediate squares, and just use
  ;;  direction-command, but we might want to identify something before we
  ;;  get closer (a monster, for example)
  (set-cursor-on-grid grid pos)
  (read-char)
  ;; TODO implement the rest, and it seems that pressing l then an arrow
  ;;  shows some weird text in the background about terminal options
  (system "setterm -cursor off"))
