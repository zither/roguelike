(import cell)
(import grid)
(import terminal)
(import common)

(define (init-visibility g)
  (empty-grid (grid-height g) (grid-width g)
	      cell-fun: (lambda (pos) 'unknown)))

(define (line-of-sight? g a b #!optional (monsters-opaque? #f))
  ;; using Bresenham's algorithm to draw a line between a and b, see if we
  ;; hit any opaque objects
  ;; see: http://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
  (if (and (= (point-x a) (point-x b))
	   (= (point-y a) (point-y b)))
      #t ; same point, trivial solution
      (let* ((x0 (point-x a)) (y0 (point-y a)) ;; TODO maybe have a generic bresenham, could be used for other things
	     (x1 (point-x b)) (y1 (point-y b))
	     (steep (> (abs (- y1 y0)) (abs (- x1 x0)))))
	(if steep
	    (let ((tmp x0))    (set! x0 y0) (set! y0 tmp)
		 (set! tmp x1) (set! x1 y1) (set! y1 tmp)))
	(if (> x0 x1)
	    (let ((tmp x0))    (set! x0 x1) (set! x1 tmp)
		 (set! tmp y0) (set! y0 y1) (set! y1 tmp)))
	(let* ((delta-x   (- x1 x0))
	       (delta-y   (abs (- y1 y0)))
	       (delta-err (/ delta-y delta-x))
	       (y-step    (if (< y0 y1) 1 -1))
	       (start     (if steep (new-point y0 x0) (new-point x0 y0)))
	       (dest      (if steep (new-point y1 x1) (new-point x1 y1))))
	  (let loop ((error        0)
		     (x            x0)
		     (y            y0))
	    (let* ((pos   (if steep (new-point y x) (new-point x y)))
		   
		   (error (+ error delta-err))
		   (cell  (grid-ref g pos)))
	      ;; TODO if we want it generic, it would be at this point that a user function would be called, I supposed
	      (cond ((equal? pos dest)          #t) ; we see it
		    ((and (opaque-cell? cell monsters-opaque?)
			  (not (equal? pos start))) #f) ; we hit an obstacle
		    (else (let ((error (if (>= error 1/2)
					   (- error 1)  error))
				(y     (if (>= error 1/2)
					   (floor (+ y y-step)) y)))
			    (loop error (+ x 1) y))))))))))

;; returns a printing function for show-grid
(define (visibility-printer view)
  (lambda (pos cell)
    ;; visibility for walls that consider only seen walls
    ;; if we have a 4-corner wall or a T wall, show it differently
    ;; depending on whether the neighbouring walls are known or not
    (define (visited? x) (or (eq? x 'visited) (eq? x 'visible)))
    (let* ((four  (four-directions pos))
	   (up    (grid-ref-check view (list-ref four 0)))
	   (down  (grid-ref-check view (list-ref four 1)))
	   (left  (grid-ref-check view (list-ref four 2)))
	   (right (grid-ref-check view (list-ref four 3)))
	   (cell  (if (or (four-corner-wall? cell) (tee-wall? cell))
		      ((cond ((four-corner-wall? cell) ;; TODO looks a lot like the last pass of dungeon generation, abstract ?
			      (cond ((and (visited? up)   (visited? down)
					  (visited? left) (visited? right))
				     make-four-corner-wall)
				    ((and (visited? down)
					  (visited? left)
					  (visited? right))
				     make-north-tee-wall)
				    ((and (visited? up)
					  (visited? left)
					  (visited? right))
				     make-south-tee-wall)
				    ((and (visited? up)
					  (visited? down)
					  (visited? right))
				     make-west-tee-wall)
				    ((and (visited? up)
					  (visited? down)
					  (visited? left))
				     make-east-tee-wall)
				    ((and (visited? up)   (visited? left))
				     make-south-east-wall)
				    ((and (visited? up)   (visited? right))
				     make-south-west-wall)
				    ((and (visited? down) (visited? left))
				     make-north-east-wall)
				    ((and (visited? down) (visited? right))
				     make-north-west-wall)
				    ((and (visited? up)   (visited? down))
				     make-vertical-wall)
				    ((and (visited? left) (visited? right))
				     make-horizontal-wall)
				    (else ;; FOO just a test, called too ofter
				     make-pillar)))
			     ((north-tee-wall? cell)
			      (cond ((and (visited? down)
					  (visited? left)
					  (visited? right))
				     make-north-tee-wall)
				    ((and (visited? down) (visited? left))
				     make-north-east-wall)
				    ((and (visited? down) (visited? right))
				     make-north-west-wall)
				    ((and (visited? left) (visited? right))
				     make-horizontal-wall)
				    (else ;; FOO
				     make-pillar))) ;; FOO last case ?
			     ((south-tee-wall? cell)
			      (cond ((and (visited? up)
					  (visited? left)
					  (visited? right))
				     make-south-tee-wall)
				    ((and (visited? up)   (visited? left))
				     make-south-east-wall)
				    ((and (visited? up)   (visited? right))
				     make-south-west-wall)
				    ((and (visited? left) (visited? right))
				     make-horizontal-wall)
				    (else
				     make-pillar))) ;; FOO
			     ((east-tee-wall? cell)
			      (cond ((and (visited? up)
					  (visited? down)
					  (visited? left))
				     make-east-tee-wall)
				    ((and (visited? up)   (visited? down))
				     make-vertical-wall)
				    ((and (visited? up)   (visited? right))
				     make-south-west-wall)
				    ((and (visited? down) (visited? right))
				     make-north-west-wall)
				    (else
				     make-pillar))) ;; FOO
			     ((west-tee-wall? cell)
			      (cond ((and (visited? up)
					  (visited? down)
					  (visited? right))
				     make-west-tee-wall)
				    ((and (visited? up)   (visited? down))
				     make-vertical-wall)
				    ((and (visited? up)   (visited? left))
				     make-south-east-wall)
				    ((and (visited? down) (visited? left))
				     make-north-east-wall)
				    (else
				     make-pillar)))) ;; FOO
		       (cell-objects cell) (cell-occupant cell))
		      cell)))
      (let ((c (print cell)))
	(case (grid-ref view pos)
	  ((visible)
	   (if (opaque-cell? cell #f)
	       (display c)
	       (terminal-print c bg: 'white fg: 'black))) ;; TODO can we have colored objects with that ? not sure
	  ((visited)
	   ;; (terminal-print c bg: 'black fg: 'white)
	   ;; these are the default colors of the terminal, and not having to
	   ;; print the control characters speeds up the game
	   ;; we don't show enemies if they would be in the fog of war
	   (cond ((cell-occupant cell) =>
		  (lambda (occ)
		    (cell-occupant-set! cell #f)
		    (display (print cell))
		    (cell-occupant-set! cell occ)))
		 (else (display c)))) ; no enemy to hide
	  ((unknown)
	   (terminal-print " ")))))))
