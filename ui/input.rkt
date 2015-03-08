#lang racket

(require racket/require)
(require (multi-in "../utilities" ("terminal.rkt" "grid.rkt"))
         (multi-in "../engine"
                   ("character.rkt" "common.rkt" "floor.rkt" "player.rkt"))
         "utilities.rkt"
         "commands.rkt"
         "help.rkt"
         "display.rkt")
(provide (all-defined-out))


;; inventory
;; 拾取物品
(new-command #\p pick-up   'inventory "Pick up an item from the ground.")
;; 丢弃物品
(new-command #\d cmd-drop  'inventory "Drop an item from the inventory.")
;; 查看背包
(new-command #\i inventory 'inventory "Display inventory.")
;; 装备物品
(new-command #\e equip     'inventory "Equip an item from inventory.")
;; 卸下物品
(new-command #\r take-off  'inventory "Take off an equipped item.")
;; 打开命令
(new-command #\o cmd-open     'exploration "Open a door or a chest.")
;; 关闭命令
(new-command #\c cmd-close    'exploration "Close a door or a chest.")
;; 上下层操作
(new-command #\t climb-stairs 'exploration "Climb stairs.")
;; 休息
(new-command #\z rest         'exploration "Rest.")
;; 喝
(new-command #\D cmd-drink 'combat "Drink a potion from inventory.")
;; 射击
(new-command #\s shoot     'combat "Shoot a target using a ranged weapon.")

;; help
;; 查询命令列表
(new-command #\? describe-commands 'help "List all commands.")
;; 查询键盘绑定 
(new-command #\^ describe-command  'help "Describe what a keybinding does.")
;; 查询字符代表的物品
(new-command #\/ describe     'help "Describe what a character represents.")
;; 列出游戏中所有字符意思
(new-command #\& describe-all 'help "List all characters known to the game.")
;; 获取当前位置的描述
(new-command #\' info         'help "Get information about the current tile.")
;; currently not working
;; (new-command #\" look         'help "Information about a given tile.")

;; debugging
(new-command #\k kill       'debugging "Insta-kill.")
;; 全图显示
(new-command #\R reveal-map 'debugging "Reaveal map.")
;; 上帝模式
(new-command #\G god-mode   'debugging "God mode.")
;; currently not working
;; (new-command #\: console    'debugging "Console.")

(new-command #\space (lambda () display "Nothing happen\n")
             'misc "Wait.")
(new-command #\q quit 'misc "Quit.")

;; for display
(reverse-command-table)

;; 键盘事件监听
(define (read-command)
  (let* ((pos   (copy-point (character-pos player)))
         (grid  (floor-map (character-floor player)))
         (x     (point-x pos))
         (y     (point-y pos))
         (char  (read-char)))
    (clear-to-bottom)
    ;; escape 1B
    (cond [(= (char->integer char) 27)
           ;; movement
           (case (which-direction?)
             ((up)    (set-point-x! pos (- x 1)))
             ((down)  (set-point-x! pos (+ x 1)))
             ((right) (set-point-y! pos (+ y 1)))
             ((left)  (set-point-y! pos (- y 1))))
           ;; tries to move to the new position
           ;; if it fails, stay where we were
           (move grid player pos)
           'move]
          [else
           ((car (dict-ref command-table char (list invalid-command))))])))
