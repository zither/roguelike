#lang racket

(provide (all-defined-out))

;; 格式化 tty 设置命令
(define (terminal-command command)
  (printf "~a~a" (integer->char #x1b) command))

;; 清除 tty 格式
(define (terminal-reset) (terminal-command "[0m"))

;; tty 颜色设置
(define (terminal-colors bg fg [bold? #f] [underline? #f])
  (terminal-command
   (format "[~a;~a~a~am"
           (case bg
             ((black) "40") ((red)     "41")
             ((green) "42") ((yellow)  "43")
             ((blue)  "44") ((magenta) "45")
             ((cyan)  "46") ((white)   "47"))
           (case fg
             ((black) "30") ((red)     "31")
             ((green) "32") ((yellow)  "33")
             ((blue)  "34") ((magenta) "35")
             ((cyan)  "36") ((white)   "37"))
           (if bold?      ";1" "")
           (if underline? ";4" ""))))

;; bright is bold, dim is regular weight, blink, reverse and hidden don't work
;; 格式化打印：背景颜色，前景颜色，粗体以及下划线
(define (terminal-print text #:bg (bg 'black) #:fg (fg 'white)
			     #:bold? (bold? #f) #:underline? (underline? #f))
  (terminal-colors bg fg bold? underline?)
  (display text)
  (terminal-reset))

;; 清除从光标到行尾
(define (clear-line)      (terminal-command "[K"))

;; 清除余下所有行
(define (clear-to-bottom) (terminal-command "[J"))

;; 光标返回原位置
(define (cursor-home)     (terminal-command "[H"))

;; 设置光标坐标
(define (set-cursor-position! x (y #f))
  (terminal-command (format "[~a~aH" x (if y (format ";~a" y) ""))))

(define (cursor-notification-head) (set-cursor-position! 2))

(define (printf-notification f . s)
  ;; 后退 60 行
  (terminal-command (format "[60C")) ; 60th column
  ;; 清除至行尾
  (clear-line)
  (apply printf f s))

;; 打开光标
(define (cursor-on)  (system "setterm -cursor on"))
;; 关闭光标
(define (cursor-off) (system "setterm -cursor off"))

;; 设置 tty   
(define (intercept-tty)
  ;; 允许原始模式输入，关闭回显，处理输出
  ;; stty 命令参考：http://www.kuqin.com/aixcmds/aixcmds5/stty.htm
  (system "stty raw -echo opost")
  ;; 关闭光标
  (cursor-off))

;; 重置 tty
(define (restore-tty)
  ;; 允许规范模式输入
  (system "stty cooked echo")
  ;; 打开光标
  (cursor-on))

;; 打开回显
(define (echo-on)  (system "stty echo"))
;; 关闭回显
(define (echo-off) (system "stty -echo"))
