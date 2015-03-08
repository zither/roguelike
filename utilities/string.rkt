#lang racket

(provide (all-defined-out))

;; ucfirst 大写第一个字母
(define (upcase-word s)
  (format "~a~a"
          (char-upcase (string-ref s 0))
          (substring s 1)))
