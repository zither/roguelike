(define (generate-level #!optional stairs-down? #!key (trace? #f) (step? #f))
  ;; TODO have a limit linked to the size of the screen, or scroll ? if scrolling, query the terminal size
  ;; for now, levels are grids of 20 rows and 60 columns, to fit in a 80x25
  ;; terminal
  (let* ((level-height 20) ;; TODO really show a border ?
	 (level-width  78) ;; TODO the full 80 or just 60 ? with 60, can display some status on the side, but there is none for the moment
	 (level (empty-grid level-height level-width
			    cell-fun: (lambda (pos) (new-solid-wall)))))
    
    (define trace 0) ;; to trace the generation of the dungeon
    (define (trace-cell)
      (let ((x (number->string (modulo trace 10))))
	(make-walkable-cell (lambda () x) #f #f)))

    (define-type room
      type
      cells ; TODO the 3 of these are sets, use hash tables for sets if it becomes slow
      walls
      connected-to)
    (define rooms '()) ;; TODO another set, see above
    (define (get-room point)
      (find (lambda (room) (member point (room-cells room))) rooms))
    (define (connected? a b)
      ;; since it's commutative, no need to check both sides
      ;; TODO need to check for a and b, since this sometimes receives #f, probably due to a bug somewhere, investigate
      (and a b (memq a (room-connected-to b))))
    (define (connect! a b)
      (if (and a b) ;; TODO same here
	  (begin (room-connected-to-set! a (cons b (room-connected-to a)))
		 (room-connected-to-set! b (cons a (room-connected-to b)))
		 #t))) ; must return true, since it's used in an and below
    
    (define (add-rectangle pos height width direction)
      ;; height and width consider a wall of one cell wide on each side
      (let* ((x     (point-x pos))
	     (y     (point-y pos))
	     (pos-x (case direction
		      ((south) x)
		      ;; expanding north, we have to move the top of the room
		      ;; up so the bottom reaches the starting point
		      ((north) (+ (- x height) 1))
		      ;; expanding east or west, position ourselves so the
		      ;; middle of the wall of the new room starts here
		      (else    (- x (floor (/ height 2))))))
	     (pos-y (case direction
		      ;; same idea as for x
		      ((east) y)
		      ((west) (+ (- y width) 1))
		      (else   (- y (floor (/ width 2)))))))
	(if (foldl ; can this new feature fit ?
	     (lambda (acc x)
	       (and acc
		    (foldl
		     (lambda (acc y)
		       (let ((p (new-point (+ x pos-x) (+ y pos-y))))
			 (and acc
			      (inside-grid? level p)
			      (wall? (grid-get level p)))))
		     #t (iota width))))
	     #t (iota height))
	    
	    (let ((new-walls '()) ; yes it can, add it
		  (inside    '()))
	      (grid-for-each
	       (lambda (p)
		 (let ((x (- (point-x p) pos-x)) (y (- (point-y p) pos-y)))
		   (grid-set!
		    level p
		    ;; find out the appropriate cell type
		    ((cond ((or (corner-wall? (grid-get level p))
				(and (or (= x 0) (= x (- height 1)))
				     (or (= y 0) (= y (- width 1)))))
			    ;; one of the four corners
			    new-corner-wall)
			   ((or (= x 0) (= x (- height 1)))
			    ;; horizontal-wall
			    (set! new-walls (cons p new-walls))
			    new-horizontal-wall)
			   ((or (= y 0) (= y (- width 1)))
			    ;; vertical wall
			    (set! new-walls (cons p new-walls))
			    new-vertical-wall)
			   ;; inside of the room
			   (else (set! inside (cons p inside))
				 (if trace?
				     trace-cell
				     new-walkable-cell)))))))
	       level
	       start-x:  pos-x  start-y:  pos-y
	       length-x: height length-y: width)

	      (if trace?
		  (begin (pp (list trace pos: (point-x pos) (point-y pos)
				   dir: direction height: height width: width))
			 (set! trace (+ trace 1))))
	      (if step?
		  (begin (show-grid level)
			 (read-line)))

	      ;; the type will be filled later
	      (make-room #f inside new-walls '()))
	    
	    #f))) ; no it can't, give up
    
    (define (add-small-room pos direction)
      ;; both dimensions 5-7 units (including walls)
      (add-rectangle pos (random-between 5 7) (random-between 5 7) direction))
    (define (add-large-room pos direction)
      ;; both dimensions 8-12 units (including walls)
      (add-rectangle pos (random-between 8 12) (random-between 8 12) direction))
    (define (add-corridor   pos direction)
      ;; width: 3, length: 5-17 (including walls)
      ;; TODO maybe wider corridors ?
      (if (or (eq? direction 'east) (eq? direction 'west))
	  ;; we generate an horizontal corridor
	  (add-rectangle pos 3 (random-between 5 17) direction)
	  (add-rectangle pos (random-between 5 17) 3 direction)))

    ;; replaces a wall (horizontal or vertical) by a door, adds the doorposts
    ;; and connects the two rooms in the graph
    ;; if we have it (and espescially if it cannot be inferred (we are placing
    ;; a door on a free space, for example)), the direction of the wall can be
    ;; given
    (define stairs-up-placed? #f)
    (define (add-door cell #!optional direction)
      ;; add the doorposts
      (for-each (lambda (post) (grid-set! level post (new-corner-wall)))
		(wall-parrallel level cell))
      ;; connect the two rooms
      (let* ((sides (wall-perpendicular level cell))
	     (dirs  (if (null? sides)
			((case direction
			   ((horizontal) up-down)
			   ((vertical)   left-right)) cell)
			sides))
	     (a     (get-room (car  dirs)))
	     (b     (get-room (cadr dirs))))
	(if (and a b)
	    (begin (grid-set! level cell (new-door)) ; put the door
		   (connect!  a b))
	    ;; when we place the first room, there is nothing to connect to,
	    ;; and we place the stairs if they were not placed already
	    (if (not stairs-up-placed?)
		(begin (grid-set! level cell (new-stairs-up))
		       (set! stairs-up-placed? #t))))))

    (define (add-random-feature start)
      ;; find in which direction to expand from this wall
      (let* ((pos  (car start))
	     (prev (cdr start)) ; type of the room we expand from
	     (direction
	      (let loop ((around     (four-directions pos))
			 (directions '(south north east west)))
		(cond ((null? around) ; walls all around
		       (random-element '(north south west east)))
		      ((and (inside-grid? level (car around))
			    (walkable-cell? (grid-get level (car around))))
		       ;; there is a free space in that direction, we must
		       ;; expand the opposite way
		       (car directions))
		      (else ;; keep looking
		       (loop (cdr around) (cdr directions))))))
	     (probabilities
	      (case prev
		((corridor)   `((0.1  corridor   ,add-corridor)
				(0.6  large-room ,add-large-room)
				(0.3  small-room ,add-small-room)))
		((large-room) `((0.6  corridor   ,add-corridor)
				(0.2  large-room ,add-large-room)
				(0.2  small-room ,add-small-room)))
		((small-room) `((0.7  corridor   ,add-corridor)
				(0.2  large-room ,add-large-room)
				(0.1  small-room ,add-small-room)))
		;; should end up here only in the first turn
		(else         `((0.4  corridor   ,add-corridor)
				(0.5  large-room ,add-large-room)
				(0.1  small-room ,add-small-room)))))
	     (r    (random-real))
	     (type (let loop ((r r)
			      (p probabilities))
		     (cond ((null? probabilities) #f) ; shouldn't happen
			   ((< r (caar p))        (car p))
			   (else                  (loop (- r (caar p))
							(cdr p))))))
	     ;; the higher it is, the more chance this room will be chosen
	     ;; as a starting point for another
	     (weight (case (cadr type)
		       ((corridor)   5)
		       ((large-room) 2)
		       ((small-room) 3)))
	     ;; returns #f or a room structure
	     (res    ((caddr type) pos direction)))
	(if res
	    (begin
	      ;; add the new room the list of rooms
	      (room-type-set! res (cadr type))
	      (set! rooms (cons res rooms))
	      (add-door pos)
	      ;; return the walls of the room "weight" times, and attach the
	      ;; type of the new room to influence room type probabilities
	      (map (lambda (x) (cons x (cadr type)))
		   (repeat weight (room-walls res))))
	    #f)))
    ;; TODO problem : the presence of + on a straight wall reveals the structure on the other side of the wall, maybe use # for all wall, but would be ugly

    ;; generate features
    (let loop ((n 500)
	       (walls (let loop ((res #f)) ; we place the first feature
			(if res
			    res
			    (loop (add-random-feature
				   (cons (random-position level) #f)))))))
      ;; although unlikely, we might run out of walls (happened once, no
      ;; idea how)
      (if (or (> n 0) (null? walls))
	  (let* ((i     (random-integer (length walls)))
		 (start (list-ref walls i)))
	    (loop (- n 1)
		  (cond ((add-random-feature start)
			 => (lambda (more)
			      (append (remove-at-index walls i) more)))
			(else walls))))))

    ;; add doors to anything that looks like a doorway
    (grid-for-each
     (lambda (pos)
       (let* ((around    (four-directions pos))
	      (up        (list-ref around 0))
	      (down      (list-ref around 1))
	      (left      (list-ref around 2))
	      (right     (list-ref around 3))
	      (direction #f))
	 ;; we must either have wall up and down, and free space left and
	 ;; right, or the other way around
	 (if (and (not (door?      (grid-get level pos))) ; not already a door
		  (not (stairs-up? (grid-get level pos)))
		  (foldl (lambda (acc cell)
			   (and acc (inside-grid? level cell)))
			 #t around)
		  (let ((c-up    (grid-get level up))
			(c-down  (grid-get level down))
			(c-left  (grid-get level left))
			(c-right (grid-get level right)))
		    (define (connection-check a b)
		      (let ((a (get-room a))
			    (b (get-room b)))
			(not (connected? a b))))
		    (or (and (corner-wall?      c-up)
			     (corner-wall?      c-down)
			     (walkable-cell?    c-left)
			     (walkable-cell?    c-right)
			     ;; must not be connected already
			     (connection-check  left right)
			     (begin (set! direction 'vertical)
				    #t))
			(and (corner-wall?      c-left)
			     (corner-wall?      c-right)
			     (walkable-cell?    c-up)
			     (walkable-cell?    c-down)
			     (connection-check  up down)
			     (begin (set! direction 'horizontal)
				    #t)))))
	     ;; yes, we have found a valid doorway, if this doorway is in an
	     ;; existing room, we would separate in into two smaller ones,
	     ;; which is no fun, so only put a door if we would open a wall
	     (let ((room (get-room pos)))
	       (if (not room)
		   (add-door pos direction))))))
     level)

    ;; to avoid dead-end corridors, any corridor connected to a single room
    ;; tries to open a door to another room
    (for-each
     (lambda (room)
       (let ((neighbors (room-connected-to room)))
	 (if (and (eq? (room-type room) 'corridor)
		  (= (length neighbors) 1))
	     (let* ((walls        (room-walls room))
		    (current-door (find (lambda (pos)
					  (door? (grid-get level pos)))
					walls))
		    (door-candidate
		     (foldl
		      ;; we want the candidate farthest from the existing door
		      ;; if there are no suitable candidates, we just choose
		      ;; the existing door
		      (lambda (best new)
			(let* ((best-dist (distance best current-door))
			       (new-dist  (distance new  current-door))
			       (max-dist  (max best-dist new-dist)))
			  (if (= max-dist best-dist)
			      best
			      new)))
		      current-door
		      (filter
		       (lambda (wall)
			 ;; to open a door, both sides must be clear
			 (let ((sides (wall-perpendicular level wall)))
			   (and (not (null? sides))
				(foldl
				 (lambda (acc new)
				   (and acc
					(inside-grid? level new)
					(walkable-cell? (grid-get level new))))
				 #t sides))))
		       walls))))
	       (if (not (eq? door-candidate current-door))
		   (add-door door-candidate)))))) ;; TODO do it only with probability p ?
     rooms)

    ;; if needed, add the stairs down on a random free square in a room
    ;; (not a corridor) TODO also, try not to put it in the way of a door
    ;; TODO try to place it as far as possible from the stairs up, see building quantifiably fun maps, or something like that on the wiki
    (if stairs-down?
	(grid-set! level
		   (random-element
		    (apply append
			   (map room-cells
				(filter (lambda (room)
					  (let ((type (room-type room)))
					    (or (eq? 'small-room type)
						(eq? 'large-room type))))
					rooms))))
		   (new-stairs-down)))
    
    level))