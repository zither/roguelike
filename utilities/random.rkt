#lang racket

(require "list.rkt")
(provide (all-defined-out))

;; 从列表中随机选取
(define (random-element l)
  (list-ref l (random (length l))))

(define (random-choice l) ; list of pairs (prob . x)
  (let loop ((r (random)) ; r 在 0 - 1 之间 
	     (l l))
    (cond ((null? l)      (error "invalid probability distribution"))
	  ((< r (caar l)) (cdar l))
	  (else           (loop (- r (caar l)) (cdr l))))))

;; 概率随机 
(define (random-boolean (p 0.5)) (< (random) p))

;; 随机 x - y 之间的数（包含 x y） 
(define (random-between x y) ; between x and y inclusively
  (+ x (random (+ 1 (- y x)))))

(define (normalize-probability-table t)
  (let ([total (apply + (map car t))])
    (map (lambda (p) 
          (cons (/ (car p) total) (cdr p))) t)))

;; returns a thunk that simulated the requested dice roll
(define (dice . kinds)
  (lambda ()
    (apply + (map (lambda (new) (+ (random new) 1)) kinds))))


(define (show-dice l)
  (let loop ((l  (group-by-identical l <))
	     (s  "")
	     (+? #f))
    (if (null? l)
	s
	(loop (cdr l)
              (format "~a~a~a~a"
                      s (if +? " + " "") (length (car l))
                      (if (= (caar l) 1) ; we don't need the d1 of Xd1
                          ""
                          (format "d~a" (caar l))))
	      #t))))
