;; maze generation using randomized Kruskal's algorithm
;; http://en.wikipedia.org/wiki/Maze_generation_algorithm
(define (generate-maze height width)
  ;; since walls must be cells, a maze of width n needs a grid of width 2n-1
  ;; same for height
  (let* ((grid-h (- (* 2 height) 1))
	 (grid-w (- (* 2 width)  1))
	 ;; cells (0,0), (0,2), (0,4), ..., (2,0), ... are always free
	 ;; the rest start out as walls, but can become free
	 (grid (empty-grid grid-h grid-w
			   cell-fun: (lambda (pos)
				       (let* ((x  (point-x pos))
					      (y  (point-y pos))
					      (mx (modulo  x 2))
					      (my (modulo  y 2)))
					 (cond ((and (= mx 0) (= my 0))
						(new-walkable-cell))
					       ((and (= mx 1) (= my 1))
						(new-corner-wall-cell))
					       ((and (= mx 1) (= my 0))
						(new-horizontal-wall-cell))
					       ((and (= mx 0) (= my 1))
						(new-vertical-wall-cell)))))))
	 (sets    (empty-grid height width
			      cell-fun: (lambda (pos) (new-set))))
	 (wall-list '()))

    ;; if the wall separates cells that are not in the same set, remove it
    ;; note : since corners do not actually separate cells, they are not
    ;; removed (and they won't need to, since they will always be linked to
    ;; another wall)
    (define (maybe-remove-wall pos)
      (let ((x    (point-x pos))
	    (y    (point-y pos))
	    (wall (grid-get grid pos)))
	(if (not (corner-wall-cell? wall))
	    (let* ((ax    (/ (if (horizontal-wall-cell? wall) (+ x 1) x) 2))
		   (ay    (/ (if (vertical-wall-cell?   wall) (+ y 1) y) 2))
		   (bx    (/ (if (horizontal-wall-cell? wall) (- x 1) x) 2))
		   (by    (/ (if (vertical-wall-cell?   wall) (- y 1) y) 2))
		   (a     (new-point ax ay))
		   (b     (new-point bx by))
		   (set-a (grid-get sets a))
		   (set-b (grid-get sets b)))
	      (if (not (set-equal? set-a set-b))
		  (let ((new (set-union set-a set-b)))
		    (grid-set! grid pos (new-walkable-cell)) ; remove wall
		    (grid-set! sets a new)
		    (grid-set! sets a new)))))))

    ;; fill the list of wall cells
    (for-each (lambda (x)
		(for-each (lambda (y)
			    (if (wall-cell? (grid-get grid (new-point x y)))
				(set! wall-list
				      (cons (new-point x y) wall-list))))
			  (iota grid-w)))
	      (iota grid-h))

    ;; randomly remove walls to get a connected area
    (set! wall-list (randomize-list wall-list))
    (for-each maybe-remove-wall wall-list)
    
    grid))
