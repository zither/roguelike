(import (path class))
(import utilities)
(import character)

(define-generic turn)

(define turn-no    0) ; in seconds, reset when the level is changed
;; to preserve the ordering from turn to turn, in case of identical speeds
(define turn-id    0)
(define turn-queue '())

(define (schedule thunk t)
  (set! turn-queue (cons (list t turn-id thunk) turn-queue))
  (set! turn-id (+ turn-id 1)))

(define (reschedule char)
  (schedule (lambda () (turn char)) (+ turn-no (character-speed char))))

(define (find-next-active)
  (let* ((minimum (fold (lambda (acc new) (min acc (car new)))
			(caar turn-queue)
			turn-queue))
	 (next (filter (lambda (x) (= (car x) minimum)) turn-queue))) ;; TODO all these list traversals might be costly
    (set! turn-no minimum)
    (for-each (lambda (x) (set! turn-queue (remove x turn-queue))) next)
    ;; order by turn-id, to preserve ordering in the case of identical speeds
    (map caddr (sort-list next (lambda (x y) (< (cadr x) (cadr y)))))))
