#lang racket

(provide (all-defined-out))

(define player #f)
;; 设置角色
(define (set-player! p)
  (set! player p))

;; 上帝模式
(define god-mode? (box #f)) ; for debugging
