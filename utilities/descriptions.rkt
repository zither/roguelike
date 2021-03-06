#lang racket

(require "class.rkt" "display.rkt")

(provide descriptions-table add-description! add-show-method)

;; for in-game help
;; alist of characters and pairs of type symbols and description strings
;; type symbols are things like 'item, 'monster, 'terrain, etc.
;; filled up automatically when methods are added to show
(define descriptions-table '())
(define (add-description! sprite type description)
  (set! descriptions-table (cons (cons sprite (cons type description))
                                 descriptions-table)))

(define-syntax-rule (add-show-method guard type sprite description)
  (begin (define-method (show (o guard)) sprite)
         (add-description! sprite type description)))
