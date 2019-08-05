;; -*- coding: utf-8; lexical-binding: t; -*-
(setq confirm-nonexistent-file-or-buffer nil)
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.
;; (defadvice package-initialize (after my-init-load-path activate)
;;   "Reset `load-path'."
;;   (push (expand-file-name "~/.emacs.d/lisp") load-path))
(package-initialize)
(push (expand-file-name "~/.emacs.d/lisp") load-path)

(let* ((minver "24.4"))
  (when (version< emacs-version minver)
    (error "Emacs v%s or higher is required." minver)))

(defvar best-gc-cons-threshold
  4000000
  "Best default gc threshold value.  Should NOT be too big!")

;; don't GC during startup to save time
(setq gc-cons-threshold most-positive-fixnum)

(setq emacs-load-start-time (current-time))

;; {{ emergency security fix
;; https://bugs.debian.org/766397
(eval-after-load "enriched"
  '(defun enriched-decode-display-prop (start end &optional param)
     (list start end)))
;; }}
;;----------------------------------------------------------------------------
;; Which functionality to enable (use t or nil for true and false)
;;----------------------------------------------------------------------------
(setq *is-a-mac* (eq system-type 'darwin))
(setq *win64* (eq system-type 'windows-nt))
(setq *cygwin* (eq system-type 'cygwin) )
(setq *linux* (or (eq system-type 'gnu/linux) (eq system-type 'linux)) )
(setq *unix* (or *linux* (eq system-type 'usg-unix-v) (eq system-type 'berkeley-unix)) )
(setq *emacs24* (>= emacs-major-version 24))
(setq *emacs25* (>= emacs-major-version 25))
(setq *emacs26* (>= emacs-major-version 26))
(setq *no-memory* (cond
                   (*is-a-mac*
                    (< (string-to-number (nth 1 (split-string (shell-command-to-string "sysctl hw.physmem")))) 4000000000))
                   (*linux* nil)
                   (t nil)))

;; @see https://www.reddit.com/r/emacs/comments/55ork0/is_emacs_251_noticeably_slower_than_245_on_windows/
;; Emacs 25 does gc too frequently
(when *emacs25*
  ;; (setq garbage-collection-messages t) ; for debug
  (setq best-gc-cons-threshold (* 64 1024 1024))
  (setq gc-cons-percentage 0.5)
  (run-with-idle-timer 5 t #'garbage-collect))

(defmacro local-require (pkg)
  `(unless (featurep ,pkg)
     (load (expand-file-name
             (cond
               ((eq ,pkg 'bookmark+)
                (format "~/.emacs.d/site-lisp/bookmark-plus/%s" ,pkg))
               ((eq ,pkg 'go-mode-load)
                (format "~/.emacs.d/site-lisp/go-mode/%s" ,pkg))
               (t
                 (format "~/.emacs.d/site-lisp/%s/%s" ,pkg ,pkg))))
           t t)))

;; *Message* buffer should be writable in 24.4+
(defadvice switch-to-buffer (after switch-to-buffer-after-hack activate)
  (if (string= "*Messages*" (buffer-name))
      (read-only-mode -1)))
			   
;----------------------------------------------------------------
;;;*Initialization
;---------------------------------------------------------------- 
;;----Package initialization & package sources
(require 'package)
(setq package-archives
      '(
        ("orgmode" . "https://orgmode.org/elpa/")
        ;("melpa" . "http://melpa.org/packages/")
		;("gnu" . "http://elpa.gnu.org/packages/");  Only for AucTeX.
		("melpa-cn" . "http://elpa.emacs-china.org/melpa/")
        ;("org-cn"   . "http://elpa.emacs-china.org/org/")
        ("gnu-cn"   . "http://elpa.emacs-china.org/gnu/");  Only for AucTeX.
        ))
(package-initialize)


;; Next line necessary after 10-12-17 package update.  let-alist was
;; downloaded as a dependency but seems we need to load it.
(require 'let-alist) ;; Cures startup problem 10-12-17?

(require 'seq)
(require 'cl)  ;; Temporary: to get loop macro, needed just below.
               ;; I think cl is automaticaly loaded by something else.
;; http://batsov.com/articles/2012/02/19/package-management-in-emacs-the-good-the-bad-and-the-ugly/
;; http://y.tsutsumi.io/emacs-from-scratch-part-2-package-management.html
(defvar required-packages
  '(ace-jump-buffer ace-jump-mode ace-jump-zap ace-link ace-window anzu 
     auctex  org    
    auctex-latexmk bind-key
    browse-kill-ring bug-hunter clippy counsel dash define-word deft diminish
    ;;dired-quick-sort edit-server elfeed elfeed-goodies expand-region
    git-timemachine  ivy-bibtex hydra ibuffer-vc imenu-anywhere ivy
    latex-extra macrostep magit matlab-mode ox-pandoc ripgrep
    s shrink-whitespace shell-pop smex swiper switch-window
    use-package wc-mode wgrep which-key wrap-region yasnippet
	)
  "A list of packages to ensure are installed at launch.")


  
;-------------------------------------------------   
;;; * Add my elisp directory and other files
;-------------------------------------------------    
;;(setq use-package-enable-imenu-support t)

;; 想查看已加载的软件包数量，它们已达到的初始化阶段以及它们花费的总时间（大致）.
(setq use-package-compute-statistics  t)  

(defun required-packages-installed-p ()
  (loop for p in required-packages
        when (not (package-installed-p p)) do (return nil)
        finally (return t)))

(unless (required-packages-installed-p)
  ;; check for new packages (package versions)
  (message "%s" "Emacs Required is now refreshing its package database...")
  (package-refresh-contents)
  (message "%s" " done.")
  ;; install the missing packages
  (dolist (p required-packages)
    (when (not (package-installed-p p))
      (package-install p))))

;; Recommended way to load use-package.
;; (add-to-list 'load-path "~/Dropbox/elisp/use-package-master")
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
  (setq use-package-verbose t)  ;; Show package load times.if the package takes longer than 0.1s to load,
                               ;; you will see a message.以便调整设置，加快启动 
							   
(setq use-package-always-ensure t) ;;默认安装 

;;Sometimes I load files outside the package system. 
;;As long as they're in a directory in my load-path, Emacs can find them.
;;http://pages.sachachua.com/.emacs.d/Sacha.html#orge96c6ed
(add-to-list 'load-path "~/.emacs.d/lisp")

(setq custom-file "~/.emacs.d/custom-settings.el")
(load custom-file t) 

(require 'use-package)

;;https://github.com/emacscollective/auto-compile
(use-package auto-compile  ;;Automatically compile Emacs Lisp libraries
  :defer t
  :config (auto-compile-on-load-mode))

;;these modes guarantee that Emacs never loads outdated byte code files.  
(setq load-prefer-newer t) 

(require 'diminish)
(require 'bind-key)
(bind-key* "C-z" 'scroll-up-keep-cursor)

;--------------------------------------------  
;;; * Load secrets
;-------------------------------------------- 
;;I keep slightly more sensitive information in a separate file 
;;so that I can easily publish my main configuration.
(load "~/.emacs.secrets" t)

;--------------------------------------------- 
;;; * Packages
;---------------------------------------------   

;; http://endlessparentheses.com/debug-your-emacs-init-file-with-the-bug-hunter.html
;; M-x bug-hunter-file [gives error about auctex].
(use-package bug-hunter
  ;; :load-path "~/dropbox/elisp/elisp-bug-hunter"
)

;-------------------------------------------------------------------------------------------------------------------------------------------------------------------
;;; * System identification
;-------------------------------------------------------------------------------------------------------------------------------------------------------------------

;; Name went from all caps in <= 24.4 to upper/lower case in 24.5.
;; In 24.5 the variable is superseded by a function.  Change later.
(defun system-is-mac ()
  (interactive)
  "Return true if system is darwin-based (Mac OS X)"
  (string-equal system-type "darwin"))

(defun system-is-windows ()
  (interactive)
  "Return true if system is windows-based"
  (string-equal system-type "windows-nt"))

(defun system-is-XPS ()
(interactive)
"Return true if the system we are running on Fran's Dell XPS 13"
(string-equal system-name "FRAN-XPS"))

(defun system-is-MBP15 ()
(interactive)
"Return true if the system we are running on MacBook Pro 15"
(string-equal system-name "MacBook-15-NJH.local"))

(defun system-is-MBP13R ()
(interactive)
"Return true if the system we are running on MacBook Pro 13 Retina"
; Not sure why name varies.
(or (string-equal system-name "MacBook-13R-NJH.local")
    (string-equal system-name "MacBook13-2013") ;; High Sierra update
    (string-equal system-name "macbook13-2013") ;; Emacs 24.5.1
    (string-equal system-name "MacBook13-2013.local")
    (string-equal system-name "Fran-MBP13.local")
    (string-equal system-name "Fran-MBP13")
    (string-equal system-name "macbook-13r-njh") ))

(defun system-is-Dell ()
(interactive)
"Return true if the system we are running on Dell Xeon"
(string-equal system-name "Dell-Nick"))

(defun system-is-Chill ()
(interactive)
"Return true if the system we are running on Chillblast"
;; (string-equal system-name "DESKTOP-II9K04F")) ; OC VII.
;; (string-equal system-name "Nick-Chill")) ; Fusion tranquility.
(string-equal system-name "Chillblast-Nick")) ; OC VII.

(defun system-is-iMac ()
(interactive)
"Return true if the system we are running on iMac"
(string-equal system-name "Nick-iMac.local"))

;-----------------------------------------
;;; * General configuration
;-----------------------------------------

;--Libraries ----------------------------
;;Neatly load some packages 
;; Dash is needed by ace-jump-buffer and wrap-region.
;;If :defer on next line then ace-jump-buffer doesn't work.
;;此包用在macbook上调用dash应用的功能，其他操作系统可以不用
(use-package dash) ;;                    :load-path "~/dropbox/elisp/dash")
(use-package s ) ;;          :defer t    :load-path "~/Dropbox/elisp/s") The long lost Emacs string manipulation library.
			 
;; 	
;;-----------------emacs基础，-------------------------
;;--------- Windows Configuration 
(setq inhibit-splash-screen t)       ; Don't want splash screen.
(setq inhibit-startup-message t)     ; Don't want any startup message.
(scroll-bar-mode 0 )                 ; Turn off scrollbars.
(tool-bar-mode 0)                  ; Turn off toolbars. (Although I changed my mind about the menu - I want that again. -----sacha chua)
(menu-bar-mode 0)                   ; No menus, but can turn back on with keypress.
(global-set-key (kbd "<C-M-f2>") 'menu-bar-mode)
(fringe-mode 0)                      ; Turn off left and right fringe cols.
(size-indication-mode)               ; Show file size in status line.
(put 'dired-find-alternate-file 'disabled nil)
(mouse-avoidance-mode 'exile)        ; Move mouse pointer out of way of cursor.
(setq visible-bell 1)                ; Turn off sound.

(display-time-mode 1)              ;Time in the modeline   the clock 
(fset 'yes-or-no-p 'y-or-n-p)        ; Change yes/no questions to y/n type.	
(electric-pair-mode t)   ;; 自动添加括号
;(use-package smart-mode-line
;;    :ensure t)         ;Display a more compact mode line    ???have a problem
;; http://pages.sachachua.com/.emacs.d/Sacha.html

(setq cursor-type 'bar)
(show-paren-mode 1)

;; Show line-number in the mode line
(line-number-mode 1)

;; Show column-number in the mode line
(column-number-mode 1)

;; Use spaces instead of tabs.
(setq-default indent-tabs-mode nil)

;; Keep point at the same screen position when scrolling.
(setq scroll-preserve-screen-position 1)

;;设置打开文件的缺省路径，这里为桌面，默认的路径为“～/” 
;;(setq default-directory "～/e:/") 
;;还不会设置

;;------navigation---------------------导航

;;一个Frame中打开多个windows后，可以通过增加如下配置，以达到在多个windows中进行跳转；
;;当窗口比较多时，可以直接使用 =(C-x o)= 进行快速跳转；
(use-package windmove
    :defer t
    :bind
    (("<f1> <right>" . windmove-right)
     ("<f1> <left>" . windmove-left)
     ("<f1> <up>" . windmove-up)
     ("<f1> <down>" . windmove-down)
     ))

;; for more window movement
(use-package switch-window
    :defer t
    :bind (("C-x o" . switch-window)))


;; Quicker window splitting
(global-set-key (kbd "C-M-0") 'delete-window) ; was digit-argument
(global-set-key (kbd "M-1")   'delete-other-windows) ; was digit-argument
; (global-set-key (kbd "M-u")   'delete-other-windows) ; u for "unique"
(global-set-key (kbd "M-2")   'split-window-vertically) ; was digit-argument
(global-set-key (kbd "M-3")   'split-window-horizontally) ; was digit-argument
; (global-set-key [f2]          'other-window)

(global-set-key (kbd "C-x ,") 'shrink-window)
(global-set-key (kbd "C-x .") 'enlarge-window) ; was set-fill-prefix

;; Different from C-M-0 when more than 2 windows.
(global-set-key [C-f2]
  '(lambda () (interactive) (other-window 1) (delete-other-windows)))

(global-set-key [C-f12]      'list-matching-lines)
(global-set-key [M-C-f12]    'toggle-frame-fullscreen)

;; Use M-f5 Hydra instead now
;; (global-set-key [S-C-f12]    'text-scale-adjust)	



;;How to change the default split-screen direction? 如何更改默认分屏方向？
;;https://stackoverflow.com/questions/7997590/how-to-change-the-default-split-screen-direction
;;(setq split-height-threshold nil)
;;(setq split-width-threshold 0)



;;(setq split-width-threshold nil) ;;for vertical split.
(setq split-width-threshold 1 )   ;;for horizontal split.


;;--------Ace-isearch     搜索能力的提升
;;Ace-isearch为集成了isearch, ace-jump-mode, avy, helm-swoop四个模式为一体的更方便的搜索体验。
;;Ace-isearch会根据输入的内容长度，来判断采用哪种模式。
;;The "default" behavior can be summrized as:
;;    + L = 1 : ace-jump-mode or avy
;;    + 1 < L < 6 : isearch
;;    + L >= 6 : helm-swoop	 

;;不想使用helm，所以未安装ace-isearch, 改做安装isearch, ace-jump-mode, avy.
(use-package isearch
  :ensure nil 
  :bind (("C-M-r" . isearch-backward-other-window)
         ("C-M-s" . isearch-forward-other-window))
  :bind (:map isearch-mode-map
              ("C-c" . isearch-toggle-case-fold)
              ("C-t" . isearch-toggle-regexp)
              ("C-^" . isearch-edit-string)
              ("C-i" . isearch-complete))
  :preface
  (defun isearch-backward-other-window ()
    (interactive)
    (split-window-vertically)
    (other-window 1)
    (call-interactively 'isearch-backward))

  (defun isearch-forward-other-window ()
    (interactive)
    (split-window-vertically)
    (other-window 1)
    (call-interactively 'isearch-forward)))

(use-package ace-jump-mode
  :defer t)

(use-package ace-link
  :disabled t
  :defer 10
  :bind ("C-c M-o" . ace-link-addr)
  :config
  (ace-link-setup-default)

  (add-hook 'org-mode-hook
            #'(lambda () (bind-key "C-c C-o" #'ace-link-org org-mode-map)))
  (add-hook 'gnus-summary-mode-hook
            #'(lambda () (bind-key "M-o" #'ace-link-gnus gnus-summary-mode-map)))
  (add-hook 'gnus-article-mode-hook
            #'(lambda () (bind-key "M-o" #'ace-link-gnus gnus-article-mode-map)))
  (add-hook 'ert-results-mode-hook
            #'(lambda () (bind-key "o" #'ace-link-help ert-results-mode-map)))
  (add-hook 'eww-mode-hook
            #'(lambda () (bind-key "f" #'ace-link-eww eww-mode-map))))

(use-package ace-mc
  :bind (("<C-m> h"   . ace-mc-add-multiple-cursors)
         ("<C-m> M-h" . ace-mc-add-single-cursor)))

(use-package ace-window
  :bind* ("<C-return>" . ace-window))

(use-package avy
  :bind* ("C-." . avy-goto-char-timer)
  :config
  (avy-setup-default))

(use-package avy-zap
  :bind (("M-z" . avy-zap-to-char-dwim)
         ("M-Z" . avy-zap-up-to-char-dwim)))

		 
;;---------------------------------------------
(use-package align
  :bind (("M-["   . align-code)
         ("C-c [" . align-regexp))
  :commands align
  :preface
  (defun align-code (beg end &optional arg)
    (interactive "rP")
    (if (null arg)
        (align beg end)
      (let ((end-mark (copy-marker end)))
        (indent-region beg end-mark nil)
        (align beg end-mark)))))
  
;;---Wgrep-----writeable global search a regular expression 可写的全局正则表达搜索，文本搜索
;;Wgrep是一个可以允许我们在grep模式下进行直接修改的工具，可以允许我们批量添加上Multiple cursors，
;;然后进行批量修改的工具。在快速修改文件时非常方便，类似于sed的批量匹配，批量修改。

(use-package wgrep
  ;;:ensure t  
  :defer t  ;;delay 
    )

(use-package wgrep-ag
    :defer t
;;  :ensure t 
)


;;-------visual  
;---Winner mode - undo and redo window configuration  撤消和重做窗口配置

;;winner-mode lets you use C-c <left> and C-c <right> to switch between window configurations. 
;;This is handy when something has popped up a buffer that you want to look at briefly before returning to whatever you were working on. 
;;When you're done, press C-c <left>.
(use-package winner
  :defer t)

  
;---undo-tree 
;People often struggle with the Emacs undo model, where there's really no concept of "redo" - you simply undo the undo.
;This lets you use C-x u (undo-tree-visualize) to visually walk through the changes you've made, 
;undo back to a certain point (or redo), and go down different branches.
;允许我们可视化地遍历您所做的更改，撤销到某个特定的点(或重做)，并沿着不同的分支进行操作。
(use-package  undo-tree 
  :ensure  t 
  :init 
    (global-undo-tree-mode ))

;; --------Hydra                                    ;;  drill  20181128  
;;https://www.youtube.com/watch?v=ONHEDj3kWrE 作者视频讲解
;; (add-to-list 'load-path "~/dropbox/elisp/hydra")
(use-package hydra
  :config
  (global-set-key (kbd "C-x m") 'hydra-major/body)
  (global-set-key (kbd "<f3>")   'hydra-bib-etc/body)
  (global-set-key (kbd "C-<f3>") 'hydra-dired/body)
)

(defhydra hydra-major (:color blue :columns 4)
  "major-mode"
  ("b" bibtex-mode "bibtex")
  ("l" latex-mode "latex")
  ("o" org-mode "org")
  ("s" lisp-mode "lisp")
  ("t" text-mode "text")
  ("c" 'toggle-truncate-lines "tog-trunc-lines")
  ("f" auto-fill-mode "auto-fill")
  ("h" html-mode "html")
  ("m" message-mode "msg")
  ("n" narrow-or-widen-dwim "narw-wide") 
  ("r" read-only-mode "read-only")
  ("u" linum-mode "lin-num")
  ("q" nil "cancel")
)
(defhydra hydra-bib-etc (:color blue :columns 4)
  "bib"
  ("<f3>" ivy-bibtex "ivy-bibtex")
  ("<f4>" ivy-resume "ivy-resume")
  ("b"
   (lambda () (interactive) (dired "~/bib"))
   "bib")
  ("d"
   (lambda () (interactive) (dired "~/texmf/bibtex/bib"))
   "texmf/bib")
  ("c"
   (lambda () (interactive) (find-file "~/texmf/bibtex/bib/cut.bib"))
   "cut")
  ("l"
   (lambda () (interactive) (find-file "~/texmf/bibtex/bib/la.bib"))
    "la")
  ("h"
   (lambda () (interactive) (find-file "~/texmf/bibtex/bib/njhigham.bib"))
   "higham")
   ("m"
    (lambda () (interactive) (find-file "~/texmf/bibtex/bib/misc.bib"))
    "misc")
   ("e"
    (lambda () (interactive) (find-file "~/texmf/bibtex/bib/ode.bib"))
    "ode")
  ("o"
    (lambda () (interactive) (switch-to-buffer "*org*"))
    "org*")
   ("s"
    (lambda () (interactive) (find-file "~/texmf/bibtex/bib/strings.bib"))
    "strings")
   ("x"
    (lambda () (interactive) (switch-to-buffer "*scratch*"))
    "scratch*")
   ("t"
    (lambda () (interactive) (switch-to-buffer "*text*"))
    "text*")
   ("z" scratch "scratch-make")
)

(defhydra hydra-dired (:color blue)
   "dired"
  ("m"
   (lambda () (interactive) (dired "~/memo"))
   "memo")
  ("t"
   (lambda () (interactive) (dired "~/tex"))
   "tex")
  ("b"
   (lambda () (interactive) (dired "~/matlab"))
   "matlab")
 ;; ("d"
  ;; (lambda () (interactive) (dired "~/dropbox"))
  ;; "dropbox")
  ("h"
   (lambda () (interactive) (dired "~/"))
   "home")
)

(global-set-key (kbd "M-<f5>")   'hydra-zoom/body)
(defhydra hydra-zoom (:color red)
    "zoom"
    ("g" text-scale-increase "in")
    ("l" text-scale-decrease "out")
    ("r" (text-scale-adjust 0) "reset")
    ;; ("r" (lambda () (interactive) (text-scale-adjust 0)) "reset")
    ("q" nil "quit"))

;; http://ericjmritz.name/2015/10/14/some-personal-hydras-for-gnu-emacs/
(defhydra hydra-move-org (:color red :columns 3)
  "Org movements"
  ("n" outline-next-visible-heading "next heading")
  ("p" outline-previous-visible-heading "prev heading")
  ("N" org-forward-heading-same-level "next heading at same level")
  ("P" org-backward-heading-same-level "prev heading at same level")
  ("u" outline-up-heading "up heading")
  ("g" org-goto "goto" :exit t))
(global-set-key (kbd "M-<f9>") 'hydra-move-org/body)

;; Hydra for modes that toggle on and off
(global-set-key
 (kbd "C-x t")
 (defhydra toggle (:color blue)
   "toggle"
   ("a" abbrev-mode "abbrev")
   ("s" flyspell-mode "flyspell")
   ("d" toggle-debug-on-error "debug")
   ("c" fci-mode "fCi")
   ("f" auto-fill-mode "fill")
   ("t" toggle-truncate-lines "truncate")
   ("w" whitespace-mode "whitespace")
   ("q" nil "cancel")))

;; Hydra for navigation
(global-set-key
 (kbd "C-x j")
 (defhydra gotoline 
   ( :pre (linum-mode 1)
	  :post (linum-mode -1))
   "goto"
   ("t" (lambda () (interactive)(move-to-window-line-top-bottom 0)) "top")
   ("b" (lambda () (interactive)(move-to-window-line-top-bottom -1)) "bottom")
   ("m" (lambda () (interactive)(move-to-window-line-top-bottom)) "middle")
   ("e" (lambda () (interactive)(end-of-buffer)) "end")
   ("c" recenter-top-bottom "recenter")
   ("n" next-line "down")
   ("p" (lambda () (interactive) (forward-line -1))  "up")
   ("g" goto-line "goto-line")
   ))

;; Hydra for some org-mode stuff
(global-set-key
 (kbd "C-c t")
 (defhydra hydra-global-org (:color blue)
   "Org"
   ("t" org-timer-start "Start Timer")
   ("s" org-timer-stop "Stop Timer")
   ("r" org-timer-set-timer "Set Timer") ; This one requires you be in an orgmode doc, as it sets the timer for the header
   ("p" org-timer "Print Timer") ; output timer value to buffer
   ("w" (org-clock-in '(4)) "Clock-In") ; used with (org-clock-persistence-insinuate) (setq org-clock-persist t)
   ("o" org-clock-out "Clock-Out") ; you might also want (setq org-log-note-clock-out t)
   ("j" org-clock-goto "Clock Goto") ; global visit the clocked task
   ("c" org-capture "Capture") ; Don't forget to define the captures you want http://orgmode.org/manual/Capture.htmlhttp://orgmode.org/manual/Capture.html
   ("l" (or )rg-capture-goto-last-stored "Last Capture")))
   
   (defhydra mz/hydra-elfeed ()
   "filter"
   ("c" (elfeed-search-set-filter "@6-months-ago +cs") "cs")
   ("e" (elfeed-search-set-filter "@6-months-ago +emacs") "emacs")
   ("d" (elfeed-search-set-filter "@6-months-ago +education") "education")
   ("*" (elfeed-search-set-filter "@6-months-ago +star") "Starred")
   ("M" elfeed-toggle-star "Mark")
   ("A" (elfeed-search-set-filter "@6-months-ago") "All")
   ("T" (elfeed-search-set-filter "@1-day-ago") "Today")
   ("Q" bjm/elfeed-save-db-and-bury "Quit Elfeed" :color blue)
   ("q" nil "quit" :color blue)
   )
   
   (defhydra imalison:hydra-font
  nil
  "Font Settings"
  ("-" imalison:font-size-decr "Decrease")
  ("d" imalison:font-size-decr "Decrease")
  ("=" imalison:font-size-incr "Increase")
  ("+" imalison:font-size-incr "Increase")
  ("i" imalison:font-size-incr "Increase")
  ("h" imalison:set-huge-font-size "Huge")
  ("a" imalison:appearance "Set Default Appearance")
  ("f" set-frame-font "Set Frame Font")
  ("0" imalison:font-size-reset "Reset to default size")
  ("8" imalison:font-size-80chars "80 chars 3 columns font size"))


;;----dired  文件管理器  (builded in)
;;Melpa最近删除了wiki包。
;;你需要从wiki中获取dired +然后自己加载它。
;;https://www.reddit.com/r/emacs/comments/7vocqa/update_on_melpa_removing_emacswiki_packages_they/

;;from  
(use-package diredfl )
	
;--which-key--or--guide-key
;Help It's hard to remember keyboard shortcuts. The guide-key package pops up help after a short delay.	
(use-package which-key
  ;; :load-path "~/dropbox/elisp/which-key"
  ;;:defer 0.2                ;和guide-key功能相同？
  ;;:config
  ;; (setq guide-key/highlight-command-regexp "rectangle")
  ;;(which-key-mode)
  ;;(which-key-setup-minibuffer)
)
	
;The guide-key可以帮助我们查看操作的快捷键，对于一些不太常用的快捷键想不起来的时候，
;可以输入快捷键的前缀后，暂停一下，Emacs即会弹出一个子窗口，
;列出当前前缀下可以选择的快捷键，及其函数名称。以方便我们进行查找。
(use-package guide-key
  :defer t
  :diminish guide-key-mode
  :config
  (progn
  (setq guide-key/guide-key-sequence '("C-x r" "C-x 4" "C-c"))
  (guide-key-mode 1)))  ; Enable guide-key-mode
  
 
;;;-------------completion---------------------
;;     company  ; the ultimate code completion backend
;;     ido      ; the other *other* search engine...
;;     helm     ; the *other* search engine for love and life ( helm to ivy  since 20181205)
;;     ivy      ; a search engine for love and life
	  
;;----company                    
(use-package company      ;;the ultimate code completion backend 
   :ensure t
   :config
      (setq company-idle-delay 0)
      (setq company-minimum-prefix-length 3)
)   
(global-company-mode t) 

;;-----ido
;;https://www.masteringemacs.org/article/introduction-to-ido-mode
;;Ido工具是为在窗口下面的状态栏中选择、显示时更清晰，操作更方便，
;;并支持模糊匹配选择，这里只保留选择文件时启动ido 。

;; Use C-f during file selection to switch to regular find-file

(setq ido-enable-flex-matching t)
(setq ido-everywhere t)
(ido-mode t)
(setq ido-auto-merge-work-directories-length 0)
(setq ido-create-new-buffer 'always)
(setq ido-enable-tramp-completion nil)
(setq ido-max-directory-size 1000000)
(setq ido-use-filename-at-point 'guess)  ;; Great on URL!
(setq ido-use-url-at-point t)
(setq ido-use-virtual-buffers t)         ;; Uses old buffers from recentf.
(setq ido-file-extensions-order '(".org" ".txt" ".py" ".emacs" ".xml" ".el" ".ini" ".cfg" ".cnf"))
(setq ido-ignore-extensions t)

;; For Mac: ignore .DS_Store files with ido mode
(add-to-list 'ido-ignore-files "\\.DS_Store")

;; http://whattheemacsd.com/
;; Just press ~ to go home when in ido-find-file.
(add-hook 'ido-setup-hook
 (lambda ()
   ;; Go straight home
   (define-key ido-file-completion-map
     (kbd "~")
     (lambda ()
       (interactive)
       (if (looking-back "/")
           (insert "~/")
         (call-interactively 'self-insert-command))))))

;;----smex 
(use-package smex     ;;smex feels like part of ido or ivy ???? Smex是Emacs的Mx增强版。它建立在Ido之上
  ;; :load-path "~/dropbox/elisp/smex-master"
  ;;:init (smex-initialize) ;;随软件启动
  :bind (("M-x" . smex)
         ("M-X" . smex-major-mode-commands)
         ;; Next is the old M-x.
         ("C-c C-c M-x" . execute-extended-command))
  :config
  ;;(setq smex-save-file "~/dropbox/.smex-items")
)

;;--------- Flyspell: spell-checking.
(use-package ispell
  :no-require t
  :bind (("C-c i c" . ispell-comments-and-strings)
         ("C-c i d" . ispell-change-dictionary)
         ("C-c i k" . ispell-kill-ispell)
         ("C-c i m" . ispell-message)
         ("C-c i r" . ispell-region)))
		 		 
;;--------ivy---swiper---counsel   
;; Ivy relies on nothing. Swiper relies on Ivy, and Counsel relies on both Swiper and Ivy.
;;ivy，ido和helm功能上有些重复，所以需要取舍，精简,完善 ！！！ 2018.11.28
;;https://github.com/lujun9972/emacs-document/blob/master/emacs-common/%E4%BB%8EHelm%E5%88%B0Ivy.org
;;Helm 和Ivy 都是补全框架.这意味着它们都是Emacs 生态系统中用来在用户输入后缩窄可供
;; 选择选项的范围的工具。很自然而然想起的通用例子就是搜索文件。
;;Helm 和Ivy 都可以帮助 用户快速搜索文件
;;from https://www.reddit.com/r/emacs/comments/910pga/tip_how_to_use_ivy_and_its_utilities_in_your/

;;https://github.com/jwiegley/dot-emacs/blob/80f70631c03b2dd4f49741478453eaf1a2fe469b/init.el
(use-package ivy
  :diminish
  :demand t

  :bind (("C-x b" . ivy-switch-buffer)
         ("C-x B" . ivy-switch-buffer-other-window)
         ("M-H"   . ivy-resume))

  :bind (:map ivy-minibuffer-map
              ("<tab>" . ivy-alt-done)
              ("SPC"   . ivy-alt-done-or-space)
              ("C-d"   . ivy-done-or-delete-char)
              ("C-i"   . ivy-partial-or-done)
              ("C-r"   . ivy-previous-line-or-history)
              ("M-r"   . ivy-reverse-i-search))

  :bind (:map ivy-switch-buffer-map
              ("C-k" . ivy-switch-buffer-kill))

  :custom
  (ivy-dynamic-exhibit-delay-ms 200)
  (ivy-height 10)
  (ivy-initial-inputs-alist nil t)
  (ivy-magic-tilde nil)
  (ivy-re-builders-alist '((t . ivy--regex-ignore-order)))
  (ivy-use-virtual-buffers t)
  (ivy-wrap t)

  :preface
  (defun ivy-done-or-delete-char ()
    (interactive)
    (call-interactively
     (if (eolp)
         #'ivy-immediate-done
       #'ivy-delete-char)))

  (defun ivy-alt-done-or-space ()
    (interactive)
    (call-interactively
     (if (= ivy--length 1)
         #'ivy-alt-done
       #'self-insert-command)))

  (defun ivy-switch-buffer-kill ()
    (interactive)
    (debug)
    (let ((bn (ivy-state-current ivy-last)))
      (when (get-buffer bn)
        (kill-buffer bn))
      (unless (buffer-live-p (ivy-state-buffer ivy-last))
        (setf (ivy-state-buffer ivy-last)
              (with-ivy-window (current-buffer))))
      (setq ivy--all-candidates (delete bn ivy--all-candidates))
      (ivy--exhibit)))

  ;; This is the value of `magit-completing-read-function', so that we see
  ;; Magit's own sorting choices.
  (defun my-ivy-completing-read (&rest args)
    (let ((ivy-sort-functions-alist '((t . nil))))
      (apply 'ivy-completing-read args)))

  :config
  (ivy-mode 1)
  (ivy-set-occur 'ivy-switch-buffer 'ivy-switch-buffer-occur))


(use-package ivy-bibtex
  :defer t
  :commands 'ivy-bibtex
  )
  
  
(use-package ivy-hydra
  :after (ivy hydra)
  :defer t)

(use-package ivy-pass
  :commands ivy-pass)



(use-package ivy-rtags
  :disabled t
  :load-path "~/.nix-profile/share/emacs/site-lisp/rtags"
  :after (ivy rtags))
  
(use-package ivy-rich
  :after ivy
  :demand t
  :config
  (ivy-rich-mode 1)
  (setq ivy-virtual-abbreviate 'full
        ivy-rich-switch-buffer-align-virtual-buffer t
        ivy-rich-path-style 'abbrev))
		

(use-package counsel
  :after ivy
  :demand t
  :diminish
  :custom (counsel-find-file-ignore-regexp
           (concat "\\(\\`\\.[^.]\\|"
                   (regexp-opt completion-ignored-extensions)
                   "\\'\\)"))
  :bind (("C-*"     . counsel-org-agenda-headlines)
         ("C-x C-f" . counsel-find-file)
         ("C-c e l" . counsel-find-library)
         ("C-c e q" . counsel-set-variable)
         ;;("C-h e l" . counsel-find-library)
         ;;("C-h e u" . counsel-unicode-char)
         ("C-h f"   . counsel-describe-function)
         ("C-x r b" . counsel-bookmark)
         ("M-x"     . counsel-M-x)
         ;; ("M-y"     . counsel-yank-pop)

         ("M-s f" . counsel-file-jump)
         ;; ("M-s g" . counsel-rg)
         ("M-s j" . counsel-dired-jump))
  :commands counsel-minibuffer-history
  :init
  (bind-key "M-r" #'counsel-minibuffer-history minibuffer-local-map)
  :config
  (add-to-list 'ivy-sort-matches-functions-alist
               '(counsel-find-file . ivy--sort-files-by-date))

  (defun counsel-recoll-function (string)
    "Run recoll for STRING."
    (if (< (length string) 3)
        (counsel-more-chars 3)
      (counsel--async-command
       (format "recollq -t -b %s"
               (shell-quote-argument string)))
      nil))

  (defun counsel-recoll (&optional initial-input)
    "Search for a string in the recoll database.
  You'll be given a list of files that match.
  Selecting a file will launch `swiper' for that file.
  INITIAL-INPUT can be given as the initial minibuffer input."
    (interactive)
    (counsel-require-program "recollq")
    (ivy-read "recoll: " 'counsel-recoll-function
              :initial-input initial-input
              :dynamic-collection t
              :history 'counsel-git-grep-history
              :action (lambda (x)
                        (when (string-match "file://\\(.*\\)\\'" x)
                          (let ((file-name (match-string 1 x)))
                            (find-file file-name)
                            (unless (string-match "pdf$" x)
                              (swiper ivy-text)))))
              :unwind #'counsel-delete-process
              :caller 'counsel-recoll)))

(use-package counsel-dash
  :bind ("C-c C-h" . counsel-dash))

(use-package counsel-gtags
  ;; jww (2017-12-10): Need to configure.
  :disabled t
  :after counsel)

(use-package counsel-osx-app
  :bind* ("S-M-SPC" . counsel-osx-app)
  :commands counsel-osx-app
  :config
  (setq counsel-osx-app-location
        (list "/Applications"
              "/Applications/Misc"
              "/Applications/Utilities"
              (expand-file-name "~/Applications")
              (expand-file-name "~/.nix-profile/Applications")
              "/Applications/Xcode.app/Contents/Applications")))

(use-package counsel-projectile
  :after (counsel projectile)
  :config
  (counsel-projectile-mode 1))

(use-package counsel-tramp
  :commands counsel-tramp)
  
							   
(use-package swiper
  :after ivy
  :bind (:map swiper-map
              ("M-y" . yank)
              ("M-%" . swiper-query-replace)
              ("C-." . swiper-avy)
              ;; ("M-c" . swiper-mc)
              ("M-c" . haba/swiper-mc-fixed)
              )
  :bind (:map isearch-mode-map
              ("C-o" . swiper-from-isearch))
  :config
  (defun haba/swiper-mc-fixed ()
    (interactive)
    (setq swiper--current-window-start nil)
    (swiper-mc)))
		 
;;http://oremacs.com/swiper/		 
;;Ivy-based interface to standard commands		 
(global-set-key (kbd "M-x") 'counsel-M-x)
(global-set-key (kbd "C-x C-f") 'counsel-find-file)
(global-set-key (kbd "<f1> f") 'counsel-describe-function)
(global-set-key (kbd "<f1> v") 'counsel-describe-variable)
(global-set-key (kbd "<f1> l") 'counsel-find-library)


;;Ivy-based interface to shell and system tools
(global-set-key (kbd "C-c g") 'counsel-git)
(global-set-key (kbd "C-c j") 'counsel-git-grep)
(global-set-key (kbd "C-c k") 'counsel-ag)
(global-set-key (kbd "C-x l") 'counsel-locate)
(global-set-key (kbd "C-S-o") 'counsel-rhythmbox)

;;ivy-resume resumes the last Ivy-based completion.
(global-set-key (kbd "C-c C-r") 'ivy-resume)	

;;This shows a custom regex builder assigned to file name completion:
(setq ivy-re-builders-alist
      '((read-file-name-internal . ivy--regex-fuzzy)
        (t . ivy--regex-plus)))	
		
			 

	

;;----------------日常工作使用Emacs
;;-------基础工具包的配置--init-daily-using
;;---Emacs中的自动保存功能，单独存储在另一个文件夹中
;; http://stackoverflow.com/questions/151945/how-do-i-control-how-emacs-makes-backup-files
(setq delete-old-versions t ; delete excess backup files silently
 delete-by-moving-to-trash t
 make-backup-files t    ; backup of a file the first time it is saved.
 backup-by-copying t    ; don't clobber symlinks
 version-control t      ; version numbers for backup files
 delete-old-versions t  ; delete excess backup files silently
 delete-auto-save-files nil  ; keep autosave when saving file
 kept-old-versions 0    ; oldest versions to keep when a new numbered backup is made (default: 2)
 kept-new-versions 10   ; newest versions to keep when a new numbered backup is made (default: 2)
 auto-save-default t    ; auto-save every buffer that visits a file
 auto-save-timeout 30   ; secs idle time before auto-save (default: 30)
 auto-save-interval 200 ; keystrokes between auto-saves (default: 300)
 vc-make-backup-files t ; backup versioned files, not done by default
)

;; Can simplify next block by setting and using one backup dir variable - TODO!
(if (system-is-windows)
(progn
(setq my-backup-dest "c:/emacs_backups/")
; Removed r: on [2018-07-01 Sun 17:55] as Emacs is writing to C: anyway!
; "ACL errors" on writing to C: in Windows 10, hence:
; (if (system-is-Chill) (setq my-backup-dest "r:/emacs_backups/") )
(if (not (file-exists-p my-backup-dest))
        (make-directory my-backup-dest t))
		
;;----在常用编辑过程中，需要对Emacs配置自动备份功能，
;;下面即为为自动保存配置一个自动保存的临时文件存储目录，配置自动备份
(setq backup-directory-alist
          `((".*" . , my-backup-dest)))
(setq auto-save-file-name-transforms   ;; Needed, else goes in curr dir!
          `((".*" , my-backup-dest t)))
))
(if (system-is-mac)
(progn
(if (not (file-exists-p "~/emacs_backups/"))
        (make-directory "~/emacs_backups/" t))
;; (make-directory "~/emacs_backups/" t)
(setq backup-directory-alist
          `((".*" . , "~/emacs_backups/")))
(setq auto-save-file-name-transforms   ;; Needed, else goes in curr dir!
          `((".*" , "~/emacs_backups/" t)))
))

;;---保存命令历史记录
;;savehist命令则是对emacs日常操作中的执行历史记录的存储功能，存储下在使用过程中的历史记录 
;;From http://www.wisdomandwonder.com/wp-content/uploads/2014/03/C3F.html
(setq savehist-file "~/.emacs.d/savehist")
(savehist-mode 1)
(setq history-length t)
(setq history-delete-duplicates t)
(setq savehist-save-minibuffer-history 1)
(setq savehist-additional-variables
      '(kill-ring
        search-ring
        regexp-search-ring))


	
;---Encoding configruation 
;; From http://www.wisdomandwonder.com/wordpress/wp-content/uploads/2014/03/C3F.html
(prefer-coding-system 'utf-8)
(when (display-graphic-p)
 (setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING)))	


;;fix chinese coding  解决中文字体显示为乱码 方框数字
 ;;(set-fontset-font "fontset-default"'gb18030' ("Microsoft YaHei" . "unicode-bmp"))
 (set-default-font "-outline-微软雅黑-normal-normal-normal-sans-21-*-*-*-p-*-iso8859-1")
 
;; Font size - no effect with fixed-sys font in Windows.
(define-key global-map (kbd "C-M-+") 'text-scale-increase)
(define-key global-map (kbd "C-M--") 'text-scale-decrease)

(define-key global-map (kbd "M-[") 'backward-sentence)
(define-key global-map (kbd "M-]") 'forward-sentence) 



  
  
;;---yasnippet
;;Snippets工具可以让我们使用定义好的代码片断，或者文本块，从而可以通过快捷键的方式快速录入。从而提高录入速度。			 
(use-package yasnippet
  :ensure t 
;;:demand t  ;;覆盖包的的延迟，强制进行加载， 即使有:bind 也不会再延迟
  :diminish yas-minor-mode
  :bind (("C-c y d" . yas-load-directory)
         ("C-c y i" . yas-insert-snippet)
         ("C-c y f" . yas-visit-snippet-file)
         ("C-c y n" . yas-new-snippet)
         ("C-c y t" . yas-tryout-snippet)
         ("C-c y l" . yas-describe-tables)
         ("C-c y g" . yas/global-mode)
         ("C-c y m" . yas/minor-mode)
         ("C-c y a" . yas-reload-all)
         ("C-c y x" . yas-expand))
   :bind (:map yas-keymap
         ("C-i" . yas-next-field-or-maybe-expand))
   :mode ("/\\.emacs\\.d/snippets/" . snippet-mode)
   ;;:config
   ;;(global-yasnippet 1);;报错
 )

 
 (use-package auto-complete
  :ensure t
  :init
  (progn
    (ac-config-default)
    (global-auto-complete-mode t)
    ))
	
;;----- Abbreviations
;;(setq abbrev-file-name "~/Dropbox/emacs_abbrev_defs")
(setq save-abbrevs t)              ;; save abbrevs when files are saved
(setq-default abbrev-mode t)

	
;;----smartparens
 (use-package smartparens
    :ensure t 
    :config
    (require 'smartparens-config)
    (setq sp-autoescape-string-quote nil)
    (--each '(css-mode-hook
              restclient-mode-hook
              js-mode-hook
              java-mode
              ruby-mode
              markdown-mode
              groovy-mode
			  latex-mode
			  bibtex-mode
              latex-extra-mode 		  
			  org-mode
			  lisp-mode
			  text-mode)
      (add-hook it 'turn-on-smartparens-mode))

  ) 
 
;;----------------------------------------------
;; Modified by NJH from
;; https://plus.google.com/113859563190964307534/posts/SK1vqiG9jv5
;; Doesn't work within expand-region, unfortunately.
(defun select-text-in-dollars()
(interactive)
(let (b1 b2)
(skip-chars-backward "^$")
(setq b1 (point))
(skip-chars-forward "^$")
(setq b2 (point))
(set-mark b1)
))
(add-hook 'LaTeX-mode-hook
          '(lambda ()
              (local-set-key (kbd "C-$") 'select-text-in-dollars)
;;              (local-unset-key (kbd "C-c C-d")) ; Prefer date.
;;              (define-key LaTeX-mode-map (kbd "<S-C-f12>") 'TeX-next-error)
	      ))
;; Not sure why this doesn't work within the add-hook.
(eval-after-load 'latex
;;     '(define-key LaTeX-mode-map (kbd "<S-C-f12>") 'TeX-next-error))
   '(progn
    (define-key LaTeX-mode-map (kbd "<S-C-f12>") 'TeX-next-error)
    (local-unset-key "\C-c\C-d") ; Prefer date.
    ))

(add-hook 'LaTeX-mode-hook #'latex-extra-mode) ; Activate latex-extra
;; Disable C-c C-u from latex-extra (prefer LaTeX-star-environment below).
;; Next line seemed to wipe out latex-extra and reftex key bindings:
;; (add-hook 'LaTeX-mode-hook '(lambda () (define-key latex-extra-mode-map "" nil)))
;; So replaced by this:
(add-hook 'LaTeX-mode-hook '(lambda () (define-key latex-extra-mode-map (kbd "C-c C-u") nil)))

;; (add-hook 'LaTeX-mode-hook
;; 	  '(lambda()
;;      	     (local-unset-key (kbd "C-c C-d")) ; Prefer date.
;; 	     ))



(use-package wrap-region
;;  :load-path "~/Dropbox/elisp/wrap-region"
  ;; Deferred loading caused by next line stops package working
  ; until mode turned off then on again!
  ; :commands wrap-region-mode
  :diminish wrap-region-mode
  :config
  (wrap-region-add-wrappers
   '(("*" "*" nil org-mode)
     ("~" "~" nil org-mode)
     ("/" "/" nil org-mode)
     ("=" "=" "+" org-mode)
     ("_" "_" nil org-mode)
     ("$" "$" nil (org-mode latex-mode))
     ("[" "]")
     ("(" ")")
     ("`" "'")
    ))
    (wrap-region-global-mode t)
    (wrap-region-mode t)
    ;; (wrap-region-add-wrapper "$" "$" nil 'latex-mode)
    ;; (wrap-region-add-wrapper "[" "]")
    ;; (wrap-region-add-wrapper "(" ")")
    ;; (wrap-region-add-wrapper "`" "'")
)

(use-package expand-region
;;  :load-path "~/Dropbox/elisp/expand-region.el-master"
;;  :commands wrap-region-mode
  :bind (("C-@"  . er/expand-region)
         ("C-~" .  er/contract-region))
  :init
  ;; Trying :init because with :config this is done after LaTeX mode loaded.
  (defun er/add-latex-mode-expansions ()
  (make-variable-buffer-local 'er/try-expand-list)
  (setq er/try-expand-list (append
                            er/try-expand-list
                            '(LaTeX-mark-environment
                              ))))
  (add-hook 'LaTeX-mode-hook 'er/add-latex-mode-expansions)

  (defun er/add-text-mode-expansions ()
    (make-variable-buffer-local 'er/try-expand-list)
    (setq er/try-expand-list (append
                              er/try-expand-list
                              '(mark-paragraph
                                mark-page))))

  (add-hook 'text-mode-hook 'er/add-text-mode-expansions)
)

;; add smart swap buffers in multi-windows
  (use-package swap-buffers
    :ensure t 
    :config
    (global-set-key (kbd "C-x 5") 'swap-buffers)
  )

;;----Multiple cursor
;;Multiple cursor是一个非常强大的多位置同时编辑的编辑模式，文档可参考：
;;这里有一个介绍详细的视频：http://emacsrocks.com/e13.html
(use-package multiple-cursors
    :defer t
    :bind
     (("C-c m t" . mc/mark-all-like-this)
      ("C-c m m" . mc/mark-all-like-this-dwim)
      ("C-c m l" . mc/edit-lines)
      ("C-c m e" . mc/edit-ends-of-lines)
      ("C-c m a" . mc/edit-beginnings-of-lines)
      ("C-c m n" . mc/mark-next-like-this)
      ("C-c m p" . mc/mark-previous-like-this)
      ("C-c m s" . mc/mark-sgml-tag-pair)
      ("C-c m d" . mc/mark-all-like-this-in-defun)))
  (use-package phi-search
    :defer t)
  (use-package phi-search-mc
    :defer t
    :config (phi-search-mc/setup-keys))
  (use-package mc-extras
    :defer t
    :config (define-key mc/keymap (kbd "C-. =") 'mc/compare-chars))
;; add multi cursors:
;;(require 'multiple-cursors)
  (global-set-key (kbd "C-S-c C-S-c") 'mc/edit-lines)
  (global-set-key (kbd "C->") 'mc/mark-next-like-this)
  (global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
  (global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)
  (global-set-key (kbd "C-S-c C-e") 'mc/edit-ends-of-lines)
  (global-set-key (kbd "C-S-c C-a") 'mc/edit-beginnings-of-lines)


;;---- Org-mode Configuration
;;Org-mode是Emacs中最常用的一个模式，在此模式下，可以支持文档编辑、任务管理、项目管理、GTD相关的任务管理等，
;;另外在此模式下，可以借助一些工具在org-mdoe下进行画图，并可以将文档导出html, markdown, pdf等格式。
;; http://irreal.org/blog/?p=2029
;;(setq org-directory "~/Dropbox/org")
(setq org-structure-template-alist
      '(("s" "#+begin_src ?\n\n#+end_src" "<src lang=\"?\">\n\n</src>")
        ("e" "#+begin_example\n?\n#+end_example" "<example>\n?\n</example>")
        ("q" "#+begin_quote\n?\n#+end_quote" "<quote>\n?\n</quote>")
        ("v" "#+BEGIN_VERSE\n?\n#+END_VERSE" "<verse>\n?\n</verse>")
        ("c" "#+BEGIN_COMMENT\n?\n#+END_COMMENT" "<comment>\n?\n</comment>")
        ("p" "#+BEGIN_PRACTICE\n?\n#+END_PRACTICE")
        ("o" "#+begin_src emacs-lisp :tangle yes\n?\n#+end_src" "<src lang=\"emacs-lisp\">\n?\n</src>")
        ("l" "#+begin_src emacs-lisp\n?\n#+end_src" "<src lang=\"emacs-lisp\">\n?\n</src>")
        ("L" "#+latex: " "<literal style=\"latex\">?</literal>")
        ("h" "#+begin_html\n?\n#+end_html" "<literal style=\"html\">\n?\n</literal>")
        ("H" "#+html: " "<literal style=\"html\">?</literal>")
        ("a" "#+begin_ascii\n?\n#+end_ascii")
        ("A" "#+ascii: ")
        ("i" "#+index: ?" "#+index: ?")
        ("I" "#+include %file ?" "<include file=%file markup=\"?\">")))

;;================================================================
;; Config for Global function
;;================================================================
;;  
;; org-mode
(add-to-list 'auto-mode-alist '("\\.org$" . org-mode))


;; set export table's format
(setq org-table-export-default-format "orgtbl-to-csv")

;;================================================================
;; Config for TODO Configuration
;;================================================================
;; This is originally assigned to C-j. See how it goes.
;; I want it so that lists easier to enter.
;; Turned off, since has unwanted effects, e.g. in todo.org.
;; Either turn on selectively or use C-j.
;; (define-key org-mode-map (kbd "<return>") 'org-return-indent)

(setq org-capture-templates
   '(("t" "TODO" entry (file+headline (concat org-directory "/todo.org")
;;                                       "Captures")
                                       "General")
       "* TODO %?\n  %U\n  %a" :prepend t :empty-lines 0)
    ("e" "CLAIMED" entry (file+headline (concat org-directory "/todo.org")
                                       "Expense claims")
       "* %?\n  %U\n  %a" :prepend t :empty-lines 0)
    ("i" "item" entry (file+headline (concat org-directory "/todo.org")
                                       "General")
       "* %?\n  %U\n  %a" :prepend t :empty-lines 0)
))
(setq org-reverse-note-order t)  ;; Refile at top instead of bottom.


;; (setq org-todo-keywords
;;       (quote (;;(sequence "TODO(t)" "NEXT(n)" "MAYBE(m)" "STARTED(s)" "APPT(a)" "|" "DONE(d)")
;;               (sequence "TODO(t)" "NEXT(n)" "STARTED(s)" "|" "DONE(d)")
;;               (sequence "WAITING(w@/!)" "HOLD(h@/!)" "|" "CANCELLED(c@/!)" "PHONE" "MEETING"))))

(setq org-todo-keywords
      (quote ((sequence "TODO(t)" "NEXT(n)" "STARTED(s)" "MAYBE(m)" "|" "DONE(d!/!)")
              (sequence "PROJECT(p)" "|" "DONE(d!/!)" "CANCELLED(c@/!)")
              (sequence "WAITING(w@/!)" "HOLD(h)" "|" "CANCELLED(c@/!)"))))

(setq org-todo-keyword-faces
      (quote (;;("NEXT" :inherit warning)
              ("PROJECT" :inherit font-lock-string-face)
              ("TODO" :foreground "red" :weight bold)
              ("NEXT" :foreground "blue" :weight bold)
              ("STARTED" :foreground "green" :weight bold)
              ("DONE" :foreground "forest green" :weight bold)
              ("WAITING" :foreground "orange" :weight bold)
              ("MAYBE" :foreground "grey" :weight bold)
              ("HOLD" :foreground "magenta" :weight bold)
              ("CANCELLED" :foreground "forest green" :weight bold)
              )))


(setq org-use-fast-todo-selection t)
(setq org-todo-state-tags-triggers
      (quote (("CANCELLED" ("CANCELLED" . t))
              ("WAITING" ("WAITING" . t))
              ("MAYBE" ("WAITING" . t))
              ("HOLD" ("WAITING") ("HOLD" . t))
              (done ("WAITING") ("HOLD"))
              ("TODO" ("WAITING") ("CANCELLED") ("HOLD"))
              ("NEXT" ("WAITING") ("CANCELLED") ("HOLD"))
              ("DONE" ("WAITING") ("CANCELLED") ("HOLD")))))


;; Now in Org 7.8.11 as org-table-transpose-table-at-point
;; http://orgmode.org/worg/org-hacks.html
;; (defun org-transpose-table-at-point ()
;;   "Transpose orgmode table at point, eliminate hlines"
;;   (interactive)
;;   (let ((contents
;;          (apply #'mapcar* #'list
;;                 ;; remove 'hline from list
;;                 (remove-if-not 'listp
;;                                ;; signals error if not table
;;                                (org-table-to-lisp)))))
;;     (delete-region (org-table-begin) (org-table-end))
;;     (insert (mapconcat (lambda(x) (concat "| " (mapconcat 'identity x " | " ) "  |\n" ))
;;                        contents ""))
;;     (org-table-align)))

;; http://www.patokeefe.com/blog
;; Modified by NJH.
(defun orgtbl-to-latex-matrix (table params)
  "Convert the Orgtbl mode TABLE to a LaTeX Matrix."
  (interactive)
  (let* ((params2
          (list
           :tstart (concat "\\[\n\\bmatrix{")
           :tend "}\n\\]"
           :lstart "" :lend " \\cr" :sep " & "
           :efmt "%s%s" :hline "\\hline")))
    (orgtbl-to-generic table (org-combine-plists params2 params))))

(defun orgtbl-insert-matrix ()
  "Insert a radio table template appropriate for this major mode."
  (interactive)
  (let* ((txt orgtbl-latex-matrix-string)
         name pos)
    (setq name (read-string "Table name: "))
    (while (string-match "%n" txt)
      (setq txt (replace-match name t t txt)))
    (or (bolp) (insert "\n"))
    (setq pos (point))
    (insert txt)
    (previous-line)
    (previous-line)))

(defcustom orgtbl-latex-matrix-string  "% BEGIN RECEIVE ORGTBL %n
% END RECEIVE ORGTBL %n
\\begin{comment}
#+ORGTBL: SEND %n orgtbl-to-latex-matrix :splice nil :skip 0

\\end{comment}\n"
  "Template for the latex matrix orgtbl translator
All occurrences of %n in a template will be replaced with the name of the
table, obtained by prompting the user."
  :type 'string
  :group 'org-table)

(if (system-is-windows)
;; Open PDFs visited in Org-mode in Sumatra (not the default choice, Acrobat).
;; http://stackoverflow.com/a/8836108/789593
(add-hook 'org-mode-hook
   '(lambda ()
      (delete '("\\.pdf\\'" . default) org-file-apps)
;;      (add-to-list 'org-file-apps '("\\.pdf\\'" . "d:\\bat\\sumatra_emacs.bat %s")))
;;      (add-to-list 'org-file-apps '("\\.pdf\\'" . "\"C:/Program Files (x86)/SumatraPDF/SumatraPDF.exe\" -reuse-instance %s")))
      (add-to-list 'org-file-apps '("\\.pdf\\'" . "\"C:/Program Files/SumatraPDF/SumatraPDF.exe\" -reuse-instance %s")))
))

;; Open PDFs in Skim instead of Acrobat.
(if (system-is-mac)
(add-hook 'org-mode-hook
   '(lambda ()
      (delete '("\\.pdf\\'" . default) org-file-apps)
      (add-to-list 'org-file-apps '("\\.pdf\\'" . "skim %s")
))))

;; Mobile org
;; Set to the name of the file where new notes will be stored
;;(setq org-mobile-inbox-for-pull "~/dropbox/org/todo.org")
;; Set to <your Dropbox root directory>/MobileOrg.
;;(setq org-mobile-directory "~/Dropbox/Apps/MobileOrg")

;; Activate additional Babel languages
(org-babel-do-load-languages
 'org-babel-load-languages
 '((calc . t)
   ))

;; Useful functions for generating html from org, e.g. to paste into
;; Wordpress.

;; http://sachachua.com/blog/2014/10/publishing-wordpress-thumbnail-images-using-emacs-org2blog/
;; http://pages.sachachua.com/.emacs.d/Sacha.html#sec-1-8-18-5
(defun sacha/org-copy-region-as-html (beg end &optional level)
  "Make it easier to copy code for Wordpress posts and other things."
  (interactive "r\np")
  (let ((org-export-html-preamble nil)
        (org-html-toplevel-hlevel (or level 3)))
    (kill-new
     (org-export-string-as (buffer-substring beg end) 'html t))))

(defun sacha/org-copy-subtree-as-html ()
  (interactive)
  (sacha/org-copy-region-as-html
   (org-back-to-heading)
   (org-end-of-subtree)))

;; For Org to convert to doc.
;; http://blog.binchen.org/posts/how-to-take-screen-shot-for-business-people-efficiently-in-emacs.html
(setq org-odt-preferred-output-format "doc")

;; This stops hitting return after a URL opening browser.
(setq org-return-follows-link nil)

;;(load-file "~/Dropbox/.emacs-mail-setup")

;; http://www.howardism.org/Technical/Emacs/orgmode-wordprocessor.html
(setq org-hide-emphasis-markers t)
(add-to-list 'org-emphasis-alist
             '("*" (:foreground "pink")
               ))

;; http://pragmaticemacs.com/emacs/prevent-comments-from-breaking-paragraphs-in-org-mode-latex-export/
;; Remove comments from org document for use with export hook
;; https://emacs.stackexchange.com/questions/22574/orgmode-export-how-to-prevent-a-new-line-for-comment-lines
(defun delete-org-comments (backend)
  (loop for comment in (reverse (org-element-map (org-element-parse-buffer)
                    'comment 'identity))
    do
    (setf (buffer-substring (org-element-property :begin comment)
                (org-element-property :end comment))
          "")))
;; Add to export hook.
(add-hook 'org-export-before-processing-hook 'delete-org-comments)

;; Execute this from scratch buffer to remove the hook:
;; (remove-hook 'org-export-before-processing-hook 'delete-org-comments)

;; http://pragmaticemacs.com/emacs/highlight-latex-text-in-org-mode/
(setq org-highlight-latex-and-related '(latex))

;; For converting org tables to csv in place.
;; Useful if have several table separated by text.
;; https://stackoverflow.com/questions/17717483/howto-convert-org-mode-table-to-original-tabbed-format
(defun org-table-transform-in-place ()
  "Just like `ORG-TABLE-EXPORT', but instead of exporting to a
  file, replace table with data formatted according to user's
  choice, where the format choices are the same as
  org-table-export."
  (interactive)
  (unless (org-at-table-p) (user-error "No table at point"))
  (org-table-align)
  (let* ((format
      (completing-read "Transform table function: "
               '("orgtbl-to-tsv" "orgtbl-to-csv" "orgtbl-to-latex"
                 "orgtbl-to-html" "orgtbl-to-generic"
                 "orgtbl-to-texinfo" "orgtbl-to-orgtbl"
                 "orgtbl-to-unicode")))
     (curr-point (point)))
    (if (string-match "\\([^ \t\r\n]+\\)\\( +.*\\)?" format)
    (let ((transform (intern (match-string 1 format)))
          (params (and (match-end 2)
               (read (concat "(" (match-string 2 format) ")"))))
          (table (org-table-to-lisp
              (buffer-substring-no-properties
               (org-table-begin) (org-table-end)))))
      (unless (fboundp transform)
        (user-error "No such transformation function %s" transform))
      (save-restriction
        (with-output-to-string
          (delete-region (org-table-begin) (org-table-end))
          (insert (funcall transform table params) "\n")))
      (goto-char curr-point)
      (beginning-of-line)
      (message "Tranformation done."))
      (user-error "Table export format invalid"))))

;;================================================================
;; Config for Tags
;;================================================================
;; Config TODO tags
(setq org-tag-alist '((:startgroup)
                      ("Develop" . ?1)
                      (:grouptags )
                      ("Simon Tschen" . ?z)
                      (:endgroup)

                      ))
;; Allow setting single tags without the menu
(setq org-fast-tag-selection-single-key (quote expert))

;; For tag searches ignore tasks with scheduled and deadline dates
(setq org-agenda-tags-todo-honor-ignore-options t)

;;================================================================
;; Config for Global column view and properties
;;================================================================
;; Set default column view headings: Task Effort Clock_Summary
;;(setq org-columns-default-format "%25ITEM %10Effort(Effort){:} %SCHEDULED %DEADLINE %11Status %20TAGS %PRIORITY %TODO")
;;(setq org-columns-default-format "%25ITEM  %9Approved(Approved?){X} %SCHEDULED %DEADLINE %11Status %TAGS %PRIORITY %TODO")
(setq org-columns-default-format
      ;;" %TODO %30ITEM %15DEADLINE %15SCHEDULED %3PRIORITY %10TAGS %5Effort(Effort){:} %6CLOCKSUM"
      " %TODO %30ITEM %15DEADLINE %15SCHEDULED %3PRIORITY %10TAGS %5Effort(Effort){:}"
      )

;; global Effort estimate values
;; global STYLE property values for completion
(setq org-global-properties (quote (
                                    ;;("Effort_ALL" . "0:15 0:30 0:45 1:00 2:00 3:00 4:00 5:00 6:00 0:00")
                                    ("Status_ALL" . "Not-start In-Progress Delay Finished Cancled")
                                    ("ID_ALL" . "")
                                    ("STYLE_ALL" . "habit"))))
;; update dynamic blocks when save file
(add-hook 'before-save-hook 'org-update-all-dblocks)

;;================================================================
;; Config for File Export To PDF                       ;;    drill
;;================================================================ 
;;https://github.com/lujianmei/emacs-in-orgfile/blob/master/03-editing/init-gtd-management.org



;;================================================================
;; Config for File Export To PDF but use beamer  导出Beamer的设置
;;================================================================ 
;; 自己设置，暂未学会
;; https://github.com/lujianmei/emacs-in-orgfile/blob/master/03-editing/init-gtd-management.org


 (use-package ox 
    :load-path "~/.emacs.d/lisp/ox.el"
    ;;:ensure nil 
  )
  
;; https://github.com/emacsmirror/org/tree/master/lisp

 (use-package ox-beamer
  :load-path "~/.emacs.d/lisp/ox-beamer.el"
  ;;:ensure nil
  )

 (use-package ox-html 
  :load-path "~/.emacs.d/lisp/ox-html.el"
    ;;:ensure nil
   )  

 (use-package org-id
   :load-path "~/.emacs.d/lisp/org-id.el"
   ;;:ensure nil
  )
  

;; 使用Listings宏包格式化源代码(只是把代码框用listing环境框起来，还需要额外的设置)
  (require 'ox-latex)
  (setq org-export-latex-listings t)
  (add-to-list 'org-latex-packages-alist '("" "listings"))  ;; 如果不希望每次都载入这些Latex包，省略这两行，
  (add-to-list 'org-latex-packages-alist '("" "xcolor"))    ;; 可以只在org文件里用LATEX_HEADER调用
;;-------------------------------------------------

  
  
;;中文目录下的 org 文件无法转换为 pdf 文件
;;这个问题可以使用 latexmk 命令配合 "%b.tex" (仅仅使用文件名，而不是文件的绝对路径) 来规避，比如：

(setq oxlc/org-latex-commands '("latexmk -xelatex -gg -pdf %b.tex"))

  
  


    

;;---Chinese-font-setup
;;https://github.com/tumashu/cnfonts
;;在Org-mode中，编辑表格并让表格的分隔线对齐是一件不太容易的事情，
;;主要原因是因为Org-mode中编辑时字母与汉字同时存在时，
;;则字母字体长度与汉字字体宽度不同的原因导致，
;;因此这里的主要解决方案是找到一种通用等宽字体，通过字体的配置来达到最终表格对齐正常。
;;感谢cnfonts的包开发者   
;;  
(use-package cnfonts
    :ensure t 
    :config
    (setq cfs-profiles
          '("program" "org-mode" "read-book"))
  )

;; -----------------------------------------
;;key bindings for org mode
;; -----------------------------------------

(global-unset-key (kbd "C-'")) ;; this setting has no use, and conflict with smart


;;(global-set-key (kbd "<f12>") 'org-agenda) ;; configured blew
(global-set-key (kbd "<f9> c") 'calendar)
(global-set-key (kbd "<f9> v") 'visible-mode)
(global-set-key (kbd "C-c c") 'org-capture)

;; add ~/notes/front-end-dev-plan.org into agenda
;; (setq org-agenda-files (list "~/notes/front-end-dev-plan.org"))
(global-set-key "\C-c a" 'org-agenda)
;; I use C-c c to start capture mode
(global-set-key (kbd "C-c c") 'org-capture)


;; config for export-mutilpul files
(global-set-key (kbd "C-<f12>") 'bh/save-then-publish)

;; config for clocking
(global-set-key (kbd "<f9> I") 'bh/punch-in)
(global-set-key (kbd "<f9> O") 'bh/punch-out)

(global-set-key (kbd "<f9> l") 'org-toggle-link-display)
(global-set-key (kbd "<f9> SPC") 'bh/clock-in-last-task)

(global-set-key (kbd "<f11>") 'org-clock-goto)
(global-set-key (kbd "C-<f11>") 'org-clock-in)  
  
;;-----Org agenda view customization configuration
;;新增新的命令
  ;;定义新的命令，来存储一些常用的搜索条件，定义需要显示的数据；
  ;;此种方法可以按下面的代码形式，对Agenda Dispather进行定制：
(setq org-agenda-custom-commands
           '(("x" agenda)
             ("y" agenda*)
             ("w" todo "WAITING")
             ("W" todo-tree "WAITING")
             ("u" tags "+boss-urgent")
             ("v" tags-todo "+boss-urgent")
             ("U" tags-tree "+boss-urgent")
             ("f" occur-tree "\\<FIXME\\>")
             ("h" . "HOME+Name tags searches") ; description for "h" prefix
             ("hl" tags "+home+Lisa")
             ("hp" tags "+home+Peter")
             ("hk" tags "+home+Kim")))  
 

;;;AUCTeX stuff.

;;https://github.com/jwiegley/dot-emacs/blob/80f70631c03b2dd4f49741478453eaf1a2fe469b/init.el
(use-package auctex
  :mode ("\\.tex\\'" . TeX-latex-mode)
  :config
  (defun latex-help-get-cmd-alist ()    ;corrected version:
    "Scoop up the commands in the index of the latex info manual.
   The values are saved in `latex-help-cmd-alist' for speed."
    ;; mm, does it contain any cached entries
    (if (not (assoc "\\begin" latex-help-cmd-alist))
        (save-window-excursion
          (setq latex-help-cmd-alist nil)
          (Info-goto-node (concat latex-help-file "Command Index"))
          (goto-char (point-max))
          (while (re-search-backward "^\\* \\(.+\\): *\\(.+\\)\\." nil t)
            (let ((key (buffer-substring (match-beginning 1) (match-end 1)))
                  (value (buffer-substring (match-beginning 2)
                                           (match-end 2))))
              (add-to-list 'latex-help-cmd-alist (cons key value))))))
    latex-help-cmd-alist)

  (add-hook 'TeX-after-compilation-finished-functions
            #'TeX-revert-document-buffer))
;;http://www.xemacs.org/Documentation/html/auctex_9.html
;; Query for master file. 在文档中键入编译命令时，emacs会首先判断当前正在编辑的文档是否为主文档。
;;如果不是，则询问主文档的位置。指定后，emacs自动将该位置添加到文档末尾，以备后续调用
;;(setq-default TeX-master nil) ;;	    ???		
;;(setq-default TeX-master "master") ; All master files called "master".

			
(use-package cdlatex
  ;;:defer t
  :load-path "~/.emacs.d/lisp/cdlatex.el"
  :config
  (add-hook 'LaTex-mode-hook 'turn-on-org-cdlatex) ;; with AUCTex LaTex mode-line
  (add-hook 'LaTex-mode-hook 'turn-on-org-cdlatex) ;; with Emacs latex mode
  (add-hook 'LaTeX-mode-hook 'turn-on-cdlatex)   ; with AUCTeX LaTeX mode
  (add-hook 'latex-mode-hook 'turn-on-cdlatex)   ; with Emacs latex mode
)
 
;; latex-preview-pane is a minor mode for Emacs that enables you 
;;to preview your LaTeX files directly in Emacs.
;;
;; 正向与逆向搜索(只对英文目录下的tex文件，才有效)
(setq TeX-PDF-mode t)
(setq TeX-source-correlate-mode t)
(setq TeX-source-correlate-method 'synctex)
(setq TeX-view-program-list
   '(("Sumatra PDF" ("\"C:/Program Files/SumatraPDF/SumatraPDF.exe\" -reuse-instance"
                      (mode-io-correlate " -forward-search %b %n ") " %o"))))
(eval-after-load 'tex
  '(progn
     (assq-delete-all 'output-pdf TeX-view-program-selection)
     (add-to-list 'TeX-view-program-selection '(output-pdf "Sumatra PDF"))))
 
;; magical syntax highlighting for LaTeX-mode buffers
;;(require-package 'magic-latex-buffer)
(use-package magic-latex-buffer
  :defer t
  :config
  (add-hook 'latex-mode-hook 'magic-latex-buffer))
;;(add-hook 'latex-mode-hook 'magic-latex-buffer)
 
;;  Adds several useful functionalities to LaTeX-mode. http://github.com/Bruce-Connor/latex-extra
(use-package latex-extra
  :defer t
  :config
  (add-hook 'latex-mode-hook 'latex-extra-mode))
;;(add-hook 'LaTeX-mode-hook #'latex-extra-mode)
 
;;; * LaTeX
(add-hook 'LaTeX-mode-hook
          (lambda ()
            (add-to-list 'TeX-command-list '("XeLaTeX" "%`xelatex%(mode)%' %t" TeX-run-TeX nil t))
            (setq TeX-command-default "XeLaTeX")
            (setq TeX-save-query  nil )
            (setq TeX-show-compilation t)))

  
;; BibTeX mode.
(require 'bibtex)
(setq bibtex-string-files '("strings.bib"))
;; Does removing trailing / on next line cure
;; bibtex-parse-buffers-stealthily errors?
(setq bibtex-string-file-path '("~/texmf/bibtex/bib"))
(setq bibtex-field-delimiters 'double-quotes)
;; Can't match my key exactly - compromise on fixed # chars from each name.
; (setq bibtex-autokey-names-stretch 3);  Use up to 4 names in total
; (setq bibtex-autokey-name-length 4);    Max no chars to use.
(setq bibtex-autokey-names-stretch 0);  Use up to 4 names in total
(setq bibtex-autokey-name-length nil);    Max no chars to use.
(setq bibtex-autokey-titlewords 0);     Don't use title in key.
(setq bibtex-autokey-titlewords-stretch 0);
(setq bibtex-text-indentation 0) ; No indentation for content.

;; From comment at https://nickhigham.wordpress.com/2016/01/06/managing-bibtex-files-with-emacs/
(defun bibtex-generate-autokey ()
  (let* ((bibtex-autokey-names nil)
  (bibtex-autokey-year-length 2)
  (bibtex-autokey-name-separator "\0")
  (names (split-string (bibtex-autokey-get-names) "\0"))
  (year (bibtex-autokey-get-year))
  (name-char (cond ((= (length names) 1) 4) ((= (length names) 2) 2) (t 1)))
  (existing-keys (bibtex-parse-keys)) key)
  (setq names (mapconcat (lambda (x)
  (substring x 0 name-char))
  names ""))
  (setq key (format "%s%s" names year))
  (let ((ret key))
  (loop for c from ?a to ?z
  while (assoc ret existing-keys)
  do (setq ret (format "%s%c" key c)))
  ret)))

;; This is for inserting text of citation within a tex file.
;; Use in TeX mode and others (with different keys).
(defun my-cite()
   (interactive)
   (let ((reftex-cite-format "%a, %t, %j %v, %p, %e: %b, %u, %s, %y %<"))
                           (reftex-citation)))
;; Above reftex-cite-format string has same effect as "'locally" but
;; with title added and author list not abbreviated.

(defun my-cite-hook ()
(local-set-key (kbd "C-c m") 'my-cite))

(global-set-key (kbd "C-c [") 'reftex-citation) ;; For all modes.

;; Customize BibTeX bibtex-clean-entry.
;; That command doesn't work properly on the Mac - unclear why.
;; E.g. https://github.com/pcdavid/config/blob/master/emacs/feature-latex.el
;; (setq bibtex-entry-format
;;       `(("opts-or-alts", "page-dashes", "required-fields",
;;          "numerical-fields", "whitespace", "last-comma", "delimiter",
;;          "unify-case", "sort-fields"
;; )))
(setq bibtex-entry-format
      `(page-dashes required-fields
         numerical-fields whitespace last-comma delimiters
         unify-case sort-fields))

(setq bibtex-field-delimiters 'double-quotes)
(setq bibtex-entry-delimiters 'braces)

;; I prefer closing brace on its own line after cleaning BibTeX entry.
(setq bibtex-clean-entry-hook 'mybibtex-clean-extra)
(defun mybibtex-clean-extra ()
  "Move final right brace to a line of its own."
  (progn (bibtex-end-of-entry) (left-char) (newline-and-indent)
         (insert "      ")))

;; These seem to work in LaTeX mode too, so no need to distinguish?
(defun my-tex-mode-hook ()
;; f5 saves file then runs LaTeX with no need to hit return.
;; http://stackoverflow.com/questions/1213260/one-key-emacs-latex-compilation
(local-set-key (kbd "<f5>") (kbd "C-x C-s C-c C-c C-j"))

(if (system-is-mac)
     ; Next line not really needed, since same as f5, but use it for
     ; consistency between Mac and Windows.
;     (local-set-key (kbd "<C-f5>") (kbd "C-x C-s C-c C-c C-j")))
     (local-set-key (kbd "<C-f5>") (kbd "C-c C-v")))
(if (system-is-windows)
    (local-set-key (kbd "<C-f5>")  'sumatra-jump-to-line))

(defun my-ref()
  (interactive)
  (insert "\\ref{}")
  (backward-char))
(local-set-key (kbd "C-c r") 'my-ref)
(defun my-eqref()
  (interactive)
  (insert "\\eqref{}")
  (backward-char))
(local-set-key (kbd "C-c e") 'my-eqref)
(local-set-key (kbd "C-c C-t C-c") `TeX-clean); Remove .log, .aux files etc.
(setq TeX-clean-confirm nil);                   Don't ask for confirmation.
(local-set-key (kbd "C-c m") 'my-cite)
)
(add-hook 'TeX-mode-hook 'my-tex-mode-hook)

;; Add return after C-c C-j.
(add-hook 'LaTeX-mode-hook
	  (lambda ()
	    (local-set-key "\C-c\C-j"
          	   (lambda () (interactive)
	           (LaTeX-insert-item) (TeX-newline)
))))

;; Command to run BibTeX directly.
;; http://comments.gmane.org/gmane.emacs.auc-tex/925
(add-hook 'LaTeX-mode-hook
	  (lambda ()
	    (local-set-key (kbd "C-c C-g")
                (lambda () (interactive) (TeX-command-menu "BibTeX")))))

;; Command to run LaTeX directly and force it always to run.
(add-hook 'LaTeX-mode-hook
	  (lambda ()
	    (local-set-key (kbd "<S-f5>")
                (lambda () (interactive) (TeX-command-menu "LaTeX")))
; 	    (local-set-key (kbd "C-c C-a")
;                (lambda () (interactive) (TeX-command-menu "LaTeX")))
            (local-set-key (kbd "C-M-[") 'LaTeX-find-matching-begin)
            (local-set-key (kbd "C-M-]") 'LaTeX-find-matching-end)
            ))

;; Check next function: is the backward sentence needed?
;; It sometimes reformats the previous line!
;; http://stackoverflow.com/questions/539984/how-do-i-get-emacs-to-fill-sentences-but-not-paragraphs
(defun fill-sentence ()
  (interactive)
  (save-excursion
    (or (eq (point) (point-max)) (forward-char))
    (forward-sentence -1)
;    (indent-relative t)
    (let ((beg (point))
          (ix (string-match "LaTeX" mode-name)))
      (forward-sentence)
      (if (and ix (equal "LaTeX" (substring mode-name ix)))
          (LaTeX-fill-region-as-paragraph beg (point))
        (fill-region-as-paragraph beg (point))))))
(global-set-key (kbd "<f7>") 'fill-sentence)

;; From comment at https://nickhigham.wordpress.com/2016/01/06/managing-bibtex-files-with-emacs/
(defvar bp/bibtex-fields-ignore-list
  '("keywords" "abstract" "file" "issn" "eprint" "issue_date"
    "articleno" "numpages" "acmid"))
(defun bp/bibtex-clean-entry-hook ()
  (save-excursion
  (let (bounds)
  (when (looking-at bibtex-entry-maybe-empty-head)
  (goto-char (match-end 0))
  (while (setq bounds (bibtex-parse-field))
  (goto-char (bibtex-start-of-field bounds))
  (if (member (bibtex-name-in-field bounds)
  bp/bibtex-fields-ignore-list)
  (kill-region (caar bounds) (nth 3 bounds))
  (goto-char (bibtex-end-of-field bounds))))))))
(add-hook 'bibtex-clean-entry-hook 'bp/bibtex-clean-entry-hook)
(global-set-key (kbd "<f7>") 'fill-sentence)

(use-package reftex
  :after auctex
  :hook (LaTeX-mode . reftex-mode))

;;; * Other misc setup stuff

;; Trying omitting this for Mac to see if clipboard problem solved.
;; If not, move back to top of file.
(if (system-is-windows)
(setq save-interprogram-paste-before-kill 1) ; Save clipbrd string before kill.
)
;; ---------------------------------------------------------------
;; Force calls to use previous instance of Emacs.
;;(require 'server)
;;(server-start)
;; (unless (server-running-p)
;;   (server-start))

;; For edit-with-emacs extension.
;;(when (require 'edit-server nil t)
 ;;   (setq edit-server-new-frame nil)
 ;;   (edit-server-start))

;; http://www.jmdeldin.com/posts/2016/sunrise-and-sunsets-in-emacs.html
(setq calendar-latitude 53.482449)
(setq calendar-longitude -2.340598)
(setq calendar-location-name "Eccles, UK")

;; For latest ORG mode downloaded by me.
;;(add-to-list 'load-path "~/Dropbox/elisp/org/lisp")
;; Next line seems needed to make org functions available outside org,
;; before org has been invoked (C-c d above).
(require 'org-install)

;; Customize status line.
(require 'diminish)
(diminish 'abbrev-mode)
(eval-after-load "org" '(diminish 'orgstruct-mode "OrgS"))

(setq frame-title-format "%f - %p"); Titlebar contains buffer name (only).

;; -----------------------------------------------------------------

;; (add-to-list 'load-path "~/dropbox/elisp/org/contrib/lisp")
;; (require 'org-drill)

;; Smooth scrolling 1 line per time (default is 5).
(setq mouse-wheel-scroll-amount '(1 ((shift) . 1) ((control) . nil)))
(setq mouse-wheel-progressive-speed nil)

;; ------------------------------------------------


(use-package shrink-whitespace
  ;; :load-path "~/dropbox/elisp/shrink-whitespace"
  :bind ("M-SPC". shrink-whitespace)
)

;; (use-package aggressive-indent-mode
;;   :load-path "~/dropbox/elisp/aggressive-indent-mode"
;;   :config
;;   (global-aggressive-indent-mode 1)
;; )

;; http://pragmaticemacs.com/emacs/instant-scratch-buffer-for-current-mode/
;;(require 'scratch)

;;(use-package git-timemachine) ;; :load-path  "~/Dropbox/elisp/git-timemachine")

;;(use-package fill-column-indicator)

;;(setq diredp-hide-details-initially-flag nil) ;; Full details in listing.

;;convert between PCRE, Emacs and rx regexp syntax 语法转换器
(use-package pcre2el
   :disabled t  ;;启动时加载时间长，且暂时我可能不会用到
;;:ensure t                  ;;ensure 会安装系统上没有的package，但不会主动更新
  :config 
  (pcre-mode)
)

(setq counsel-fzf-cmd "/home/zamansky/.fzf/bin/fzf -f %s")

;;Interface Enhancement 界面增强

;; http://endlessparentheses.com/faster-pop-to-mark-command.html
;; When popping the mark, continue popping until the cursor
;; actually moves
(defadvice pop-to-mark-command (around ensure-new-position activate)
  (let ((p (point)))
    (dotimes (i 10)
      (when (= p (point)) ad-do-it))))
(setq set-mark-command-repeat-pop t)

;; http://endlessparentheses.com/improving-emacs-file-name-completion.html
;; Extensions to ignore in filename completion in minibuffer.
(mapc (lambda (x)
        (add-to-list 'completion-ignored-extensions x))
      '(".aux" ".blg" ".exe"
        ".meta" ".out" ".pdf"
        ".synctex.gz" ".tdo" ".toc"
        "-pkg.el" "-autoloads.el"
        "auto/"))

;; ----------------------------------
;; Recentf  is a minor mode that builds a list of recently opened files.

(use-package recentf
  :init
  ;; Must come before mode is loaded, else my recent file not loaded.
    (setq recentf-save-file "~/.recentf")
 ;   (setq recentf-save-file (concat (getenv "HOME") "/.recentf"))
  :bind ("M-0" . recentf-open-files)
  :config
  ;; http://www.xsteve.at/prg/emacs/power-user-tips.html
  (setq recentf-max-saved-items 500)
  (setq recentf-max-menu-items 60)
  (setq recentf-auto-cleanup 120) ; Must use custom?
  (recentf-mode 1)
)

;; ;; http://www.xsteve.at/prg/emacs/power-user-tips.html
;; ;; Next line must come before mode is turned on.
;; (setq recentf-save-file "~/.recentf")
;; (recentf-mode 1)
;; (setq recentf-max-saved-items 500)
;; (setq recentf-max-menu-items 60)
;; (setq recentf-auto-cleanup 120) ; Must use custom?

(global-set-key (kbd "M-0") 'recentf-open-files)

(defun xsteve-ido-choose-from-recentf ()
  "Use ido to select a recently opened file from the `recentf-list'"
  (interactive)
  (let ((home (expand-file-name (getenv "HOME"))))
    (find-file
     (ido-completing-read "Recentf open: "
                          (mapcar (lambda (path)
                                    (replace-regexp-in-string home "~" path))
                                  recentf-list)
                          nil t))))

;; http://www.masteringemacs.org/articles/2011/01/27/find-files-faster-recent-files-package/
(defun ido-recentf-open ()
  "Use `ido-completing-read' to \\[find-file] a recent file"
  (interactive)
  (if (find-file (ido-completing-read "Find recent file: " recentf-list))
      (message "Opening file...")
    (message "Aborting")))

;; For Mac, useful to replace home by tilde.
;; Was C-x C-r, but I prefer to keep that for find-file-read-only.
(if (system-is-mac)
    (global-set-key (kbd "C-0") 'xsteve-ido-choose-from-recentf))
(if (system-is-windows)
    (global-set-key (kbd "C-0") 'ido-recentf-open))

; ----------------------------------------------------------------
; Interactive macro expansion as used by Jwiegley.
; https://github.com/joddie/macrostep
(use-package macrostep
  ;; :load-path "~/dropbox/elisp/macrostep"
  :bind ("C-c e m" . macrostep-expand))


; ------------------------------------------------------------
;; http://pragmaticemacs.com/emacs/dont-kill-buffer-kill-this-buffer-instead/
(global-set-key (kbd "C-x k") 'kill-this-buffer)

;; (add-to-list 'load-path "~/dropbox/elisp/browse-kill-ring")
(use-package browse-kill-ring
   :config
   (browse-kill-ring-default-keybindings)
)

;; http://www.blogbyben.com/2013/08/a-tiny-eshell-add-on-jump-to-shell.html
;; (add-to-list 'load-path "~/dropbox/elisp/shell-pop")
(use-package shell-pop
:defer t)
(global-set-key [S-f3] 'shell-pop) ;; Default is buffer's dir.

;; Reload .emacs.
(global-set-key (kbd "M-<f12>")
  '(lambda () (interactive) (load-file "~/.emacs")))

;; These not needed with Magit 2.1.0.
;; git-modes
;; (add-to-list 'load-path "~/dropbox/elisp/git-modes-master")
;; require 'git-commit-mode)
;; (require 'gitconfig-mode)
;; (require 'gitignore-mode)

;; -----------------------------------------------------------------

;; Can't get this to work.  Nothing specfically on this found via Google.
;; I want to use this in all modes.
; (global-unset-key (kbd "C-c &"))
(global-set-key (kbd "C-x &") nil) ;; Remove prefix command set by yasnippet.
(global-set-key (kbd "C-c &") 'reftex-view-crossref)
;; (define-key (current-global-map) "\C-c&" 'reftex-view-crossref)
; (define-key global-map "\C-c&" nil)


; -------------------------------------------------------------------
;; ;; Navigate use-package definitions in .emacs.
;; ;; http://irreal.org/blog/?p=3979
(use-package imenu-anywhere
   ;; :load-path "~/dropbox/elisp/imenu-anywhere"
   :init (global-set-key (kbd "C-c =") 'imenu-anywhere)
)
;; No longer needed, since use-package now does this itself.
;;   :config (defun jcs-use-package ()
;;             (add-to-list 'imenu-generic-expression
;;              '("Used Packages"
;;                "\\(^\\s-*(use-package +\\)\\(\\_<.+\\_>\\)" 2)))
;;   (add-hook 'emacs-lisp-mode-hook #'jcs-use-package))


;; ----------------------------------------------------
                                        ;
;; http://oremacs.com/2015/05/22/define-word/
(use-package define-word
;;  :load-path "~/dropbox/elisp/define-word"
  :bind (("M-g d" . define-word-at-point)
         ("M-g M-d" . define-word-at-point)
         ("M-g D" . define-word)))

;; org2blog
;; (add-to-list 'load-path "~/dropbox/elisp/org2blog-org-8-support")
;;(add-to-list 'load-path "~/dropbox/elisp/org2blog")
;;(add-to-list 'load-path "~/dropbox/elisp/metaweblog-master")
;;(require 'org2blog-autoloads)
                                       ; (require 'xml-rpc)
;; Load construct that has Wordpress username and password.
;;(load-file "~/Dropbox/.emacs-wordpress")
;;(setq org2blog/wp-show-post-in-browser 'show)
;; Next two lines cause <pre> tags to be converted to WP sourcecode blocks.
;; (require 'htmlize)
;; (setq org2blog/wp-use-sourcecode-shortcode t)

;; (require 'netrc) ;; or nothing if already in the load-path
;; (setq blog (netrc-machine (netrc-parse "~/.netrc") "myblog" t))
;; (setq org2blog/wp-blog-alist
;;       '(("my-blog"
;;          :url "http://nickhigham.wordpress.com/xmlrpc.php"
;;          :username (netrc-get blog "login")
;;          :password (netrc-get blog "password"))))

;;(winner-mode 1)   ;;seem to be unnecessary

;; Yow has gone in 24.4.
;; (setq yow-file "~/dropbox/yow.lines" )

(add-hook 'matlab-mode-hook
	  '(lambda()
     	     (local-unset-key (kbd "M-j")) ; Prefer mine.
	     ))

;; Don't let the cursor go into minibuffer prompt
;; http://ergoemacs.org/emacs/emacs_stop_cursor_enter_prompt.html
(setq minibuffer-prompt-properties (quote (read-only t point-entered minibuffer-avoid-prompt face minibuffer-prompt)))

;; -----------------------------------------------------------
;; Bookmarks

;; Save bookmarks after every change.
(setq bookmark-save-flag 1)

(global-set-key (kbd "C-x [") 'point-to-register)
(global-set-key (kbd "C-x ]") 'jump-to-register)

(global-set-key [M-f6] 'write-region)
;; -----------------------------------------------------------

;;; * My macros

;; Load my keyboard macros.
;; (load-file "~/Dropbox/mymacros.macs")
;; (global-set-key (kbd "C-c n") 'norm2); Fails due to assumed search term.

;; Recorded again using regexp. For several norms on same line must
;; convert starting from end of line due to greedy .*!
(fset 'norm2
   (lambda (&optional arg) "Keyboard macro." (interactive "p") (kmacro-exec-ring-item (quote ([201326629 92 92 124 92 40 46 42 92 41 92 92 124 95 50 13 92 92 110 111 114 109 116 123 92 49 125 13 46] 0 "%d")) arg)))
(global-set-key (kbd "C-c n") 'norm2)

;; Macro to convert "From.." to "Dear..." in mail buffer.
(fset 'my-make-dear
   (lambda (&optional arg) "Keyboard macro." (interactive "p") (kmacro-exec-ring-item (quote ([C-kp-home 19 45 61 kp-home kp-down 67108896 C-kp-right C-kp-right C-kp-right 23 68 101 97 114 32 C-kp-right kp-left 44 11 return] 0 "%d")) arg)))
(add-hook 'mail-mode-hook
           (lambda () (define-key mail-mode-map (kbd "<f6>") 'my-make-dear)))
;;(add-hook 'mail-mode 'flyspell-mode)

;; (add-hook 'mail-mode-hook
;; 	  '(lambda()
;;              (local-set-key (kbd "f6") 'my-make-dear)
;; 	     ))

;; Autoindent (return acts as C-j).
(define-key global-map (kbd "RET") 'newline-and-indent)

;; http://www.wisdomandwonder.com/article/9862/handling-4-kinds-of-return-in-org-mode
(defun gcr/smart-open-line ()
  "Insert a new line, indent it, and move the cursor there.
   The current line is left alone, a new line is inserted, indented,
   and the cursor is moved there."
  (interactive)
  (move-end-of-line nil)
  (newline-and-indent))
(global-set-key (kbd "S-<return>") 'gcr/smart-open-line)
;; Next command avoids any special Org indentation.
(global-set-key (kbd "C-M-<return>") 'electric-indent-just-newline)

;;------------------------
;;(add-to-list 'load-path "~/dropbox/elisp/git-gutter-master")
;;(require 'git-gutter)
;;(global-set-key [S-f12] 'git-gutter-mode)

;;------------------------
;; Case changes
;;(require 'toggle-case); http://www.northbound-train.com/emacs.html
;;(global-set-key [f8]     'toggle-case)
;; (global-set-key [C-f8]   'downcase-word)
;; (global-set-key [S-f8]   'capitalize-word)
;;(global-set-key [M-f8]   'title-case-string-region-or-line)
;; (global-set-key [S-M-f8] 'upcase-word)

;; https://github.com/mrkkrp/fix-word
;; http://emacs.stackexchange.com/questions/13970/fixing-double-capitals-as-i-type/13975#13975
;; These work backwards when point between words.
;;(use-package fix-word
;;  :load-path "~/dropbox/elisp/fix-word"
;;  :bind (("S-M-<f8>" . fix-word-upcase)
;;         ("C-<f8>"   . fix-word-downcase)
;;         ("S-<f8>"   . fix-word-capitalize)
;;))

;;(use-package fireplace
;;  :load-path "~/dropbox/elisp/fireplace"
;;)

;; http://ergoemacs.org/emacs/modernization_upcase-word.html
(defun toggle-letter-case ()
  "Toggle the letter case of current word or text selection.
Toggles between: `all lower`, `Init Caps`, `ALL CAPS`."
 (interactive)
 (let (p1 p2 (deactivate-mark nil) (case-fold-search nil))
   (if (region-active-p)
       (setq p1 (region-beginning) p2 (region-end))
     (let ((bds (bounds-of-thing-at-point 'word) ) )
       (setq p1 (car bds) p2 (cdr bds)) ) )

   (when (not (eq last-command this-command))
     (save-excursion
       (goto-char p1)
       (cond
        ((looking-at "[[:lower:]][[:lower:]]") (put this-command 'state "all lower"))
        ((looking-at "[[:upper:]][[:upper:]]") (put this-command 'state "all caps") )
        ((looking-at "[[:upper:]][[:lower:]]") (put this-command 'state "init caps") )
        ((looking-at "[[:lower:]]") (put this-command 'state "all lower"))
        ((looking-at "[[:upper:]]") (put this-command 'state "all caps") )
        (t (put this-command 'state "all lower") ) ) ) )

   (cond
    ((string= "all lower" (get this-command 'state))
     (upcase-initials-region p1 p2) (put this-command 'state "init caps"))
    ((string= "init caps" (get this-command 'state))
     (upcase-region p1 p2) (put this-command 'state "all caps"))
    ((string= "all caps" (get this-command 'state))
     (downcase-region p1 p2) (put this-command 'state "all lower")) )
   ) )
(global-set-key [C-S-f8] 'toggle-letter-case)

(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)
;; Now can make region lowercase with C-x C-l or uppercase with C-x C-u.
;;------------------------

(global-set-key [S-insert]    'indent-rigidly)
(global-set-key [S-kp-insert] 'indent-rigidly)
;; Mac has no insert key, so:
(if (system-is-mac)
    (global-set-key (kbd "s-i") 'indent-rigidly)) ;; s = cmd

; http://stackoverflow.com/questions/6156286/emacs-lisp-call-function-with-prefix-argument-programmatically
(defun my-shift-left ()
  (interactive)
  (let ((current-prefix-arg '(-1))) ; C-u -1
  (call-interactively 'indent-rigidly)))
(global-set-key [S-delete]    'my-shift-left)
(global-set-key [S-kp-delete] 'my-shift-left)

;; How to get sharp key on Macbook Pro!
(if (system-is-mac)
(global-set-key (kbd "M-9") '(lambda () (interactive) (insert "#"))))

;;----------------------------------------------
;; http://xahlee.org/emacs/effective_emacs.html
;; But why the constant "50"?  Seems arbitrary!

(defun next-user-buffer ()
  "Switch to the next user buffer.
User buffers are those whose name does not start with *."
  (interactive)
  (next-buffer)
  (let ((i 0))
    (while (and (string-match "^*" (buffer-name)) (< i 50))
      (setq i (1+ i)) (next-buffer) )))

(defun previous-user-buffer ()
  "Switch to the previous user buffer.
User buffers are those whose name does not start with *."
  (interactive)
  (previous-buffer)
  (let ((i 0))
    (while (and (string-match "^*" (buffer-name)) (< i 50))
      (setq i (1+ i)) (previous-buffer) )))

(defun next-emacs-buffer ()
  "Switch to the next emacs buffer.
Emacs buffers are those whose name starts with *."
  (interactive)
  (next-buffer)
  (let ((i 0))
    (while (and (not (string-match "^*" (buffer-name))) (< i 50))
      (setq i (1+ i)) (next-buffer) )))

(defun previous-emacs-buffer ()
  "Switch to the previous emacs buffer.
Emacs buffers are those whose name starts with *."
  (interactive)
  (previous-buffer)
  (let ((i 0))
    (while (and (not (string-match "^*" (buffer-name))) (< i 50))
      (setq i (1+ i)) (previous-buffer) )))

;; http://jcubic.wordpress.com/2012/01/26/switching-between-buffers-with-the-same-major-mode-in-emacs
(defun buffer-same-mode (change-buffer-fun)
  (let ((current-mode major-mode)
        (next-mode nil))
    (while (not (eq next-mode current-mode))
      (funcall change-buffer-fun)
      (setq next-mode major-mode))))

(defun previous-buffer-same-mode ()
  (interactive)
  (buffer-same-mode #'previous-buffer))

(defun next-buffer-same-mode ()
  (interactive)
  (buffer-same-mode #'next-buffer))

(global-set-key (kbd "M-p")   'previous-user-buffer)
(global-set-key (kbd "M-n")   'next-user-buffer)
(global-set-key (kbd "C-S-p") 'previous-emacs-buffer)
(global-set-key (kbd "C-S-n") 'next-emacs-buffer)

(global-set-key (kbd "C-M-n") 'previous-buffer-same-mode)
(global-set-key (kbd "C-M-p") 'next-buffer-same-mode)

;; ------------deft(need to be modified)--------------------------
;; http://pragmaticemacs.com/emacs/make-quick-notes-with-deft/
;;https://github.com/jrblevin/deft
;;Deft is an Emacs mode for quickly browsing, filtering, and editing directories of plain text notes
(use-package deft)
(setq deft-directory "~/memo")
(setq deft-extensions '("org"))
(setq deft-default-extension "org")
(setq deft-text-mode 'org-mode)
(setq deft-use-filename-as-title t)
(setq deft-use-filter-string-for-filename t)
(setq deft-auto-save-interval 0)

;; ----------------------RSS-------------------------------------------------
;; Elfeed
;; From http://cestlaz.github.io/posts/using-emacs-29%20elfeed/#.WLd6QxxBSRd
;;(setq elfeed-db-directory "~/Dropbox/elfeeddb")

(use-package elfeed
 :ensure t
 :bind (:map elfeed-search-mode-map
	      ("q" . bjm/elfeed-save-db-and-bury)
	      ("Q" . bjm/elfeed-save-db-and-bury)
	      ("m" . elfeed-toggle-star)
	      ("M" . elfeed-toggle-star)
		  ("j" . mz/hydra-elfeed/body)
	)
)

(defun elfeed-mark-all-as-read ()
      (interactive)
      (mark-whole-buffer)
      (elfeed-search-untag-all-unread))

;;functions to support syncing .elfeed between machines
;;makes sure elfeed reads index from disk before launching
(defun bjm/elfeed-load-db-and-open ()
  "Wrapper to load the elfeed db from disk before opening"
  (interactive)
  (elfeed-db-load)
  (elfeed)
  (elfeed-search-update--force))

;;write to disk when quiting
(defun bjm/elfeed-save-db-and-bury ()
  "Wrapper to save the elfeed db to disk before burying buffer"
  (interactive)
  (elfeed-db-save)
  (quit-window))

;; [2017-03-05 Sun 14:16]
;; Why is the next def causing error about missing elfeed-expose?
;; It was working the other day!
;; http://pragmaticemacs.com/category/elfeed/
; (defalias 'elfeed-toggle-star
;  (elfeed-expose #'elfeed-search-toggle-all 'star))

;;(use-package elfeed-goodies   ;;没有用过
;;  :ensure t
;;  :config
;;  (elfeed-goodies/setup))

(setq elfeed-feeds
      '(
        "http://xkcd.com/rss.xml"                ;; comics XKCD
        "http://irreal.org/blog/?feed=rss2"      ;; blog emacs
        "http://pragmaticemacs.com/feed/"        ;; blog Emacs
        "https://nibandmuck.com/"                ;; Nib and Muck
        "http://sachachua.com/blog/category/emacs-news/feed" ;; blog Emacs
		"http://www.howardism.org/index.xml"     ;; My Blog
        "http://planet.emacsen.org/atom.xml"     ;; Emacs RSS
        "http://sachachua.com/blog/category/emacs-news/feed"
        "http://endlessparentheses.com/atom.xml" ;; Emacs Blog
        "http://www.masteringemacs.org/feed/"    ;; Emacs Blog
        "http://emacs-fu.blogspot.com/feeds/posts/default"
        "http://emacsredux.com/atom.xml"         ;; Emacs Blog
        "http://www.lunaryorn.com/feed.atom"     ;; Emacs Blog
        "http://emacshorrors.com/feed.atom"
        "http://swannodette.github.com/atom.xml" ;; David Nolen, duh.
        "http://batsov.com/atom.xml"             ;; Bozhidar Batsov

        "https://apod.nasa.gov/apod.rss"         ;; Nasa's Picture of the Day
        "http://twogreenleaves.org/index.php?feed=rss"
         )
)


;; Seems to need older version of Org to install!
;; (use-package elfeed-org
;;   :ensure t
;;   :config
;;   (elfeed-org)
;;   (setq rmh-elfeed-org-files (list "~/Dropbox/org/elfeed.org")))

 

   
;; -------------------------------------------------
;; --------------------------------------------------------
;; http://endlessparentheses.com/emacs-narrow-or-widen-dwim.html
;; http://irreal.org/blog/?p=4771

(defun narrow-or-widen-dwim (p)
  "Widen if buffer is narrowed, narrow-dwim otherwise.
Dwim means: region, org-src-block, org-subtree, or defun,
whichever applies first. Narrowing to org-src-block actually
calls `org-edit-src-code'.

With prefix P, don't widen, just narrow even if buffer is
already narrowed."
  (interactive "P")
  (declare (interactive-only))
  (cond ((and (buffer-narrowed-p) (not p)) (widen))
        ((region-active-p)
         (narrow-to-region (region-beginning) (region-end)))
        ((derived-mode-p 'org-mode)
         ;; `org-edit-src-code' is not a real narrowing
         ;; command. Remove this first conditional if you
         ;; don't want it.
         (cond ((ignore-errors (org-edit-src-code))
                (delete-other-windows))
               ((ignore-errors (org-narrow-to-block) t))
               (t (org-narrow-to-subtree))))
        ((derived-mode-p 'latex-mode)
         (LaTeX-narrow-to-environment))
        (t (narrow-to-defun))))

;; Next line gives an error for me.
;; (define-key endless/toggle-map "n" #'narrow-or-widen-dwim)

;; This line actually replaces Emacs' entire narrowing
;; keymap, that's how much I like this command. Only copy it
;; if that's what you want.
(define-key ctl-x-map "n" #'narrow-or-widen-dwim)
(add-hook 'LaTeX-mode-hook
          (lambda () (define-key LaTeX-mode-map "\C-xn" nil)))

;;----------------------------------------------
;; From Emacs Starter Kit. See
(defun eval-and-replace ()
  "Replace the preceding sexp with its value."
  (interactive)
  (backward-kill-sexp)
  (condition-case nil
      (prin1 (eval (read (current-kill 0)))
             (current-buffer))
    (error (message "Invalid expression")
           (insert (current-kill 0)))))
;; (global-set-key (kbd "C-M-e") 'eval-and-replace)
;; Clashes with latex-extra command.

(defun lorem ()
  "Insert a lorem ipsum."
  (interactive)
  (insert
   "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do "
    "eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim"
    "ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut "
    "aliquip ex ea commodo consequat. Duis aute irure dolor in "
    "reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla "
    "pariatur. Excepteur sint occaecat cupidatat non proident, sunt in "
    "culpa qui officia deserunt mollit anim id est laborum."))



;;----------------------------------------------
;; popup tips
;; (add-to-list 'load-path "~/Dropbox/elisp/clippy-el-master")
(use-package clippy
  :config
  (global-set-key [M-f3] 'clippy-describe-function)
)

;;----------------------------------------------

;;(require 'sl)       ; Train!
;;(require 'zone)     ; Zone out!  M-x zone, M-x zone-leave-me-alone.

;;(when (system-is-windows)
;; This works fine on Windows but gives jerky repeating cursor on Mac.
;; Need a different approach for Mac - TODO!
;; Change cursor type for insert and overwrite modes.
;; http://www.emacswiki.org/emacs/ChangingCursorDynamically
;;(require 'cursor-chg)  ; Load the library
;; (toggle-cursor-type-when-idle 1) ; Turn on cursor change when Emacs is idle
;;(change-cursor-mode 1) ; Turn on change for overwrite, read-only, and input mode
;; Actual cursor type is set in custom below.
;;)

;;------------------------------------------------------------
;; http://xahlee.org/emacs/emacs_dired_open_file_in_ext_apps.html
(defun open-in-external-app ()
  "Open the current file or dired marked files in external app.
Works in Microsoft Windows, Mac OS X, Linux."
  (interactive)

  (let ( doIt
         (myFileList
          (cond
           ((string-equal major-mode "dired-mode") (dired-get-marked-files))
           (t (list (buffer-file-name))) ) ) )

    (setq doIt (if (<= (length myFileList) 5)
                   t
                 (y-or-n-p "Open more than 5 files?") ) )

    (when doIt
      (cond
       ((string-equal system-type "windows-nt")
        (mapc (lambda (fPath) (w32-shell-execute "open" (replace-regexp-in-string "/" "\\" fPath t t)) ) myFileList)
        )
       ((string-equal system-type "darwin")
        (mapc (lambda (fPath) (shell-command (format "open \"%s\"" fPath)) )  myFileList) )
       ((string-equal system-type "gnu/linux")
        (mapc (lambda (fPath) (shell-command (format "xdg-open \"%s\"" fPath)) ) myFileList) ) ) ) ) )
(global-set-key (kbd "<M-S-f9>") 'open-in-external-app)

;; http://whattheemacsd.com/setup-dired.el-02.html
;; Avoid uninteresting lines at top and bottom.
(defun dired-back-to-top ()
  (interactive)
  (beginning-of-buffer)
  (dired-next-line 4))

;;(define-key dired-mode-map
;;  (vector 'remap 'beginning-of-buffer) 'dired-back-to-top)

;;(defun dired-jump-to-bottom ()
 ;; (interactive)
;;  (end-of-buffer)
;;  (dired-next-line -1))

;;(define-key dired-mode-map
 ;; (vector 'remap 'end-of-buffer) 'dired-jump-to-bottom)

;;------------------------------------------------------------
(when (system-is-windows)
(use-package dired-quick-sort
  :ensure t
  :config
    (setq ls-lisp-use-insert-directory-program t)      ;; use external ls
    (setq insert-directory-program "e:/cygwin/bin/ls") ;; ls program name
  ;; (when (system-is-mac)
  ;;   (setq ls-lisp-use-insert-directory-program t)      ;; use external ls
  ;;   (setq insert-directory-program "ls")          ;; ls program name
  ;; )
  (dired-quick-sort-setup)
)
)

;; -----  Screen.

;; Try these further [2015-11-01 Sun 21:53]:
;; (use-package frame-fns
;;   :load-path "~/dropbox/elisp/frame-fns.el"
;; )
;;(use-package frame-cmds
;;  :load-path "~/dropbox/elisp/frame-cmds.el"
;;)

(add-to-list 'default-frame-alist '(background-color . "black"))
(add-to-list 'default-frame-alist '(foreground-color . "white"))
;; Are last two lines needed - seemed to have no effect.
;; Black b/g was set by line -4 of emacs-custom_windows.
(set-foreground-color "white")
(set-background-color "black")
(set-face-background 'region "gray") ; Set region background color
(set-cursor-color "yellow")

;; (add-to-list 'custom-theme-load-path "~/Dropbox/elisp/emacs-color-theme-solarized-master")
;; (load-theme 'solarized-dark t)



;; Initial frame size.
;; Seems this must come after the above, else window is shorter!

;;(if (system-is-windows)
;;(setq default-frame-alist
;;      '((height . 25) (width . 125)  ))) 

(defun my/set-initial-frame ()
  (let* ((base-factor 0.70)
	(a-width (* (display-pixel-width) base-factor))
        (a-height (* (display-pixel-height) base-factor))
        (a-left (truncate (/ (- (display-pixel-width) a-width) 2)))
	(a-top (truncate (/ (- (display-pixel-height) a-height) 2))))
    (set-frame-position (selected-frame) a-left a-top)
    (set-frame-size (selected-frame) (truncate a-width)  (truncate a-height) t)))
(setq frame-resize-pixelwise t)
(my/set-initial-frame)

(add-to-list 'default-frame-alist '(fullscreen . maximized));;开启emacs，窗口设置为最大化


(if (system-is-MBP15)
(setq default-frame-alist
      '((top . 35) (left . 550)      ; Little effect with smaller values!
        (width . 80) (height . 35)
        )))

(if (system-is-MBP13R)
(setq default-frame-alist
      '((top . 35) (left . 390)
        (width . 80) (height . 30)
        )))

;; Smaller screen for Dell XPS.
(if (system-is-XPS)
(setq default-frame-alist
      '((top . 10) (left . 495)
        (width . 80) (height . 30)
        )))

;; 27" screen for Chillblast.
;; (if (or (system-is-Chill) (system-is-iMac) (system-is-Dell))
(if (or (system-is-Chill) (system-is-iMac))
(setq default-frame-alist
      '((top . 35) (left . 1600)
        (width . 81) (height . 55)
        )))

;; 24" screen for Dell.
(if (system-is-Dell)
(setq default-frame-alist
      ;; '((top . 10) (left . 1025)
      '((top . 10) (left . 1010)
        (width . 81) (height . 48)
        )))



;; Turn on font-lock mode to color text in certain modes.
(global-font-lock-mode t)

(if (system-is-mac)
    (progn
    ;; Ensure aspell is used on Mac; not necessary on Windows..
    (setq ispell-program-name "/opt/local/bin/aspell")
    ;; Necessary for Auctex to be found with my Emacs 24 setup on Mac.
    (add-to-list 'load-path "/usr/share/emacs/site-lisp")
    ;; Next setting seems to be enough to get Mac Emacs to not open new
    ;; window when called from command line.
    ;; http://stackoverflow.com/questions/945709/emacs-23-os-x-multi-tty-and-emacsclient
    (setq ns-pop-up-frames nil)
))

;; http://xahlee.org/emacs/emacs_copy_cut_current_line.html
;; Allows C-w, M-w to work on line if no region marked.
;; This requires transient-mark-mode to be on.
(defadvice kill-ring-save (before slick-copy activate compile)
  "When called interactively with no active region, copy the current line."
  (interactive
   (if mark-active
       (list (region-beginning) (region-end))
     (progn
       (message "Current line is copied.")
       (list (line-beginning-position) (line-beginning-position 2)) ) ) ))

(defadvice kill-region (before slick-copy activate compile)
  "When called interactively with no active region, cut the current line."
  (interactive
   (if mark-active
       (list (region-beginning) (region-end))
     (progn
       (list (line-beginning-position) (line-beginning-position 2)) ) ) ))



;; Let minibuffer grow for ido
;; http://stackoverflow.com/questions/1775898/emacs-disable-line-truncation-in-minibuffer-only
(setq resize-mini-windows t)    ; grow and shrink as necessary
(setq max-mini-window-height 3) ; grow up to max of 3 lines
;; Next line needed for the above to work, since I set truncate-lines to
;; t below.
(add-hook 'minibuffer-setup-hook
      (lambda () (setq truncate-lines nil)))

;; ibuffer-vc
;; (add-to-list 'load-path "~/Dropbox/elisp/ibuffer-vc-master")
(use-package ibuffer-vc)


;; -----------------------------------------------------------------
(defun xah-select-text-in-quote ()
  "Select text between the nearest left and right delimiters.
Delimiters here includes the following chars: \"<>(){}[]“”‘’‹›«»「」『』【】〖〗《》〈〉〔〕（）
This command does not properly deal with nested brackets.
URL `http://ergoemacs.org/emacs/modernization_mark-word.html'
Version 2015-05-16"
  (interactive)
  (let (-p1
        -p2
        (-skipChars "^\"<>(){}[]“”‘’‹›«»「」『』【】〖〗《》〈〉〔〕（）"))
    (skip-chars-backward -skipChars)
    (setq -p1 (point))
    (skip-chars-forward -skipChars)
    (setq -p2 (point))
    (set-mark -p1)))

(defun mydoi ()
  "With point inside a DOI field of a bib entry goes object with that DOI."
  (interactive)
  (xah-select-text-in-quote)
  (browse-url
   (concat
    "https://doi.org/" (buffer-substring (region-beginning) (region-end))
  )))
;; -----------------------------------------------------------------

;; http://xahlee.blogspot.com/2011/11/emacs-lisp-example-title-case-string.html
;; For title-case-string-region-or-line
;;(require 'xfrp_find_replace_pairs)
;;(require 'xeu_elisp_util)

;; http://emacs.wordpress.com/2007/01/16/quick-and-dirty-code-folding
(defun jao-selective-display ()
"Activate selective display based on the column at point"
(interactive)
(set-selective-display
(if selective-display
nil
(+ 1 (current-column)))))
(global-set-key [M-f7] 'jao-selective-display)

;; https://twitter.com/danjacka/status/356728771430199296/photo/1
(defun bigtext-mode ()
     (interactive)
     (setq cursor-type nil)
     (text-scale-increase 8))

(global-set-key (kbd "<C-S-f6>") 'repeat-complex-command)

;;(require 'bubble-buffer)
;;(global-set-key [f9] 'bubble-buffer-next)
;;(global-set-key [(shift f9)] 'bubble-buffer-previous)
;;(setq bubble-buffer-omit-regexp "\\(^ .+$\\|\\*Messages\\*\\|*compilation\\*\\|\\*.+output\\*$\\|\\*TeX Help\\*$\\|\\*vc-diff\\*\\|\\*Occur\\*\\|\\*grep\\*\\|\\*cvs-diff\\*\\)")

; ------------------------------------------------
; http://emacsredux.com/blog/2013/05/22/smarter-navigation-to-the-beginning-of-a-line/
(defun smarter-move-beginning-of-line (arg)
  "Move point back to indentation of beginning of line.

Move point to the first non-whitespace character on this line.
If point is already there, move to the beginning of the line.
Effectively toggle between the first non-whitespace character and
the beginning of the line.

If ARG is not nil or 1, move forward ARG - 1 lines first.  If
point reaches the beginning or end of the buffer, stop there."
  (interactive "^p")
  (setq arg (or arg 1))

  ;; Move lines first
  (when (/= arg 1)
    (let ((line-move-visual nil))
      (forward-line (1- arg))))

  (let ((orig-point (point)))
    (back-to-indentation)
    (when (= orig-point (point))
      (move-beginning-of-line 1))))

(global-set-key (kbd "C-a") 'smarter-move-beginning-of-line)

; ------------------------------------------------

;; http://camdez.com/blog/2013/11/14/emacs-show-buffer-file-name/
;; Shows buffer filename and copies it to kill ring.
(defun show-buffer-file-name ()
  "Show the full path to the current file in the minibuffer."
  (interactive)
  (let ((file-name (buffer-file-name)))
    (if file-name
        (progn
          (message file-name)
          (kill-new file-name))
      (error "Buffer not visiting a file"))))

;; http://whattheemacsd.com/
(defun rename-current-buffer-file ()
  "Renames current buffer and file it is visiting."
  (interactive)
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not (and filename (file-exists-p filename)))
        (error "Buffer '%s' is not visiting a file!" name)
      (let ((new-name (read-file-name "New name: " filename)))
        (if (get-buffer new-name)
            (error "A buffer named '%s' already exists!" new-name)
          (rename-file filename new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil)
          (message "File '%s' successfully renamed to '%s'"
                   name (file-name-nondirectory new-name)))))))
(global-set-key (kbd "C-x C-r") 'rename-current-buffer-file)

;; Modified by NJH from rename-current-buffer-file.
(defun rename-current-buffer ()
  "Renames current buffer and associates it to a file."
  (interactive)
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not (and filename (file-exists-p filename)))
        (error "Buffer '%s' is not visiting a file!" name)
      (let ((new-name (read-file-name "New name: " filename)))
        (if (get-buffer new-name)
            (error "A buffer named '%s' already exists!" new-name)
;;        (rename-file filename new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
;;        (set-buffer-modified-p nil)
          (message "Buffer '%s' successfully renamed to '%s'"
                   name (file-name-nondirectory new-name)))))))
(global-set-key (kbd "C-x C-n") 'rename-current-buffer)

;; From https://github.com/jwiegley/dot-emacs/blob/master/init.el
(defun kill-to-end-of-buffer ()
  (interactive)
  (kill-region (point) (point-max)))

;; http://irreal.org/blog/?p=4926
(use-package char-menu
  :ensure t
  ;; bind ("H-s" . char-menu)
  :config (setq char-menu '("—" "‘’" "“”" "…" "«»" "–"
                            ("Typography" "•" "©" "†" "‡" "°" "·" "§" "№" "★")
                            ("Math"       "≈" "≡" "≠" "∞" "×" "±" "∓" "÷" "√")
                            ("Arrows"     "←" "→" "↑" "↓" "⇐" "⇒" "⇑" "⇓"))))

;; ----------------------------------
;; ibuffer

(setq ibuffer-shrink-to-minimum-size t)
(setq ibuffer-always-show-last-buffer nil)
(setq ibuffer-sorting-mode 'recency)
(setq ibuffer-use-header-line t)
(global-set-key [C-f9] 'ibuffer)

;; http://martinowen.net/blog/2010/02/tips-for-emacs-ibuffer.html
;; Can't get wildcards on name containing emacs to work.
(setq ibuffer-saved-filter-groups
          (quote (("default"
; Can't get name with wildcards to work!
;                   ("emacs-config" (name . "^\\*.emacs\\*$"))
;                   ("Emacs Lisp" (mode . emacs-lisp-mode))
                   ("Emacs Lisp" (or (mode . emacs-lisp-mode)
;                                     (name . "emacs.org")
                                     (name . "^.\\*emacs.\\*$")
;                                     (name . "^\\*emacs\\*$")
;                                      (name . "\*emacs\*")
                   ))
                   ("LaTeX" (or (mode . latex-mode)
                      (mode . LaTeX-mode)
                      (mode . bibtex-mode)
                      (mode . reftex-mode)))
;                   ("TeX" (mode . latex-mode))
                   ("MATLAB" (mode . matlab-mode))
                   ("Org" (mode . org-mode))
                   ("Text" (mode . text-mode))
                   ("Web" (mode . html-mode))
                   ("dired" (or (mode . dired-mode)))
                   ("Emacs*" (or
                             (name . "^\\*Apropos\\*$")
                             (name . "^\\*Buffer List\\*$")
                             (name . "^\\*Compile-Log\\*$")
                             (name . "^\\*Help\\*$")
                             (name . "^\\*info\\*$")
                             (name . "^\\*Occur\\*$")
                             (name . "^\\*scratch\\*$")
                             (name . "^\\*Messages\\*$")))
))))
(setq ibuffer-show-empty-filter-groups nil)
(add-hook 'ibuffer-mode-hook
	  '(lambda ()
	     (ibuffer-auto-mode 1)
	     (ibuffer-switch-to-saved-filter-groups "default")))
(setq ibuffer-expert t)

;; http://www.emacswiki.org/emacs/IbufferMode
;; Switching to ibuffer puts the cursor on the most recent buffer
(defadvice ibuffer (around ibuffer-point-to-most-recent) ()
  "Open ibuffer with cursor pointed to most recent buffer name"
  (let ((recent-buffer-name (buffer-name)))
    ad-do-it
    (ibuffer-jump-to-buffer recent-buffer-name)))
(ad-activate 'ibuffer)

;; ----------------------------------

;; Next function is crude, but works on Scan!
;; http://xahlee.org/emacs/emacs_dired_open_file_in_ext_apps.html
(defun open-document-somehow ()
  (interactive)
  (shell-command (concat "\"" (car (dired-get-marked-files)) "\"") ) )
(global-set-key (kbd "C-S-o") 'open-document-somehow)

;; This enables Ctrl-x < and Ctrl-x > - scroll left and right.
(put 'scroll-left 'disabled nil)

;; Adapted from http://geosoft.no/development/emacs.html
;; Cf. \cite[p.~22]{glic97}.
(defun scroll-down-keep-cursor ()
   ;; Scroll the text one line down while keeping the cursor
   (interactive)
   (next-line)
   (scroll-down 1))
(defun scroll-up-keep-cursor ()
   ;; Scroll the text one line up while keeping the cursor
   (interactive)
   (previous-line)
   (scroll-up 1))
(global-set-key [\C-up]      'scroll-down-keep-cursor)
(global-set-key (kbd "C-q")  'scroll-down-keep-cursor)
(global-set-key [\C-down]    'scroll-up-keep-cursor)
(global-set-key (kbd "C-z")  'scroll-up-keep-cursor)

;; CUA mode
;; http://trey-jackson.blogspot.com/2008/10/emacs-tip-26-cua-mode-specifically.html
;; (setq cua-enable-cua-keys nil) ; Keep Emacs keys (C-c, C-v, C-x).
(setq cua-enable-cua-keys t)    ; Use new C-c, C-v, C-x.
(setq cua-remap-control-z nil)  ; Don't remap C-z.
;; (setq cua-remap-control-x nil)  ; Don't remap C-x.  ;; No such option!
;; (setq cua-highlight-region-shift-only t) ;; no transient mark mode
;; (setq cua-toggle-set-mark nil) ;; original set-mark behavior, i.e. no transient-mark-mode
(setq cua-prefix-override-inhibit-delay 0.35) ; default 0.2
(cua-mode)

;; Next function is kill-word from simple.el modified to use viper-forward-word
(defun njh-kill-word1 (arg)
  "Kill characters forward until encountering the end of a word.
With argument ARG, do this that many times."
  (interactive "p")
  (kill-region (point) (progn (viper-forward-word arg) (point))))

;; (defun njh-kill-word (arg)
;;    ;; Modification of kill word to leave only one space between words.
;;    (interactive "p")
;;    (kill-word arg)
;;    (just-one-space))

(defun njh-kill-word2 (arg)
   ;; Modification of kill word to behave like DelRightWord() in TSE-Pro.
   (interactive "p")
   (cond
         ((bolp)  ;; True if point is at start of line
               (njh-kill-word1 arg)  (delete-horizontal-space) )
         ((eolp)  ;; True if point is at end of line
               (delete-forward-char 1) )
         (t (njh-kill-word1 arg) (just-one-space) )
   )
)
(global-set-key (kbd "M-d") 'njh-kill-word2)
(global-set-key (kbd "C-f") 'njh-kill-word2)

(global-set-key (kbd "M-f") 'mark-word)  ; default M-@

;;(require 'iy-go-to-char)
;;(global-set-key (kbd "M-m") 'iy-go-to-char)

;; ----------------------------------------------
;; Hippie expand.
(setq hippie-expand-try-functions-list
      '(try-expand-dabbrev
       try-expand-dabbrev-all-buffers
       pcomplete
       try-expand-dabbrev-from-kill
       try-complete-file-name-partially
       try-complete-file-name
       try-expand-all-abbrevs
       try-expand-list
       try-expand-line
       try-complete-lisp-symbol-partially
       try-complete-lisp-symbol))

;; http://stackoverflow.com/questions/2149899/code-completion-key-bindings-in-emacs
;; Function to implement a smarter TAB (EmacsWiki)
(defun smart-tab ()
  "This smart tab is minibuffer compliant: it acts as usual in
    the minibuffer. Else, if mark is active, indents region. Else if
    point is at the end of a symbol, expands it. Else indents the
    current line."
  (interactive)
  (if (minibufferp)
      (unless (minibuffer-complete)
        (hippie-expand nil))
    (if mark-active
        (indent-region (region-beginning)
                       (region-end))
      ;; NJH mod - completion except when on spaces at start of line.
      (if (looking-at "^ *")
         (indent-for-tab-command)
         (hippie-expand nil)
          ))))
;;      (if (looking-at "\\_>") ; Matches empty string at and of symbol.
;;         (hippie-expand nil)
;;        (indent-for-tab-command)))))
(global-set-key (kbd "TAB") 'smart-tab)




;; ---------------------------------------------------
;; http://ergoemacs.org/emacs/emacs_using_register.html
(defun copy-to-register-1 ()
  "Copy current line or text selection to register 1.
See also: 'paste-from-register-1', 'copy-to-register'."
  (interactive)
  (let* (
         (bds (get-selection-or-unit 'line ))
         (inputStr (elt bds 0) )
         (p1 (elt bds 1) )
         (p2 (elt bds 2) )
         )
    (copy-to-register ?1 p1 p2)
    (message "copied to register 1: %s." inputStr)
))

(defun paste-from-register-1 ()
  "Paste text from register 1.
See also: 'copy-to-register-1', 'insert-register'."
  (interactive)
  (insert-register ?1))

(global-set-key [C-f6]       'copy-to-register-1)   ; A la TSEPro.
(global-set-key [S-f6]       'paste-from-register-1)

;;----------------------------------------------------
;; http://ergoemacs.org/emacs/elisp_compact_empty_lines.html
;; Suspect not most elegant coding, but not trivial to do this other ways!
(defun xah-clean-whitespace ()
  "Delete trailing whitespace, and replace sequence of newlines into just 2.
Work on whole buffer, or text selection."
  (interactive)
  (let* (
         (bds (get-selection-or-unit 'buffer))
         (p1 (elt bds 1))
         (p2 (elt bds 2))
         )
    (save-excursion
      (save-restriction
        (narrow-to-region p1 p2)
        (progn
          (goto-char (point-min))
          (while (search-forward-regexp " +\n" nil "noerror")
            (replace-match "\n") ))
        (progn
          (goto-char (point-min))
          (while (search-forward-regexp "\n\n\n+" nil "noerror")
            (replace-match "\n\n") )) )) ))
(global-set-key [C-f11] 'xah-clean-whitespace)
;;----------------------------------------------------

;; Column line where text should be wrapped
(setq-default fill-column 75)
(defun toggle-fill-column ()
    "Toggle setting fill column between 72 and 75"
    (interactive)
    (setq fill-column (if (= fill-column 75) 72 75)))
(global-set-key [S-f2]     'toggle-fill-column)
(global-set-key [S-C-f2]   'fci-mode)

;; Next line not a good idea as it affects all searches, incl. RefTeX.
;; (setq-default case-fold-search nil) ; Make searches case sensitive.
;;(global-set-key (kbd "C-c t") 'toggle-case-fold-search)

;; http://ergoemacs.org/emacs/elisp_datetime.html
(defun insert-long-date ()
  "Insert a nicely formatted date string."
  (interactive)
  (insert (format-time-string "%A %B %-e, %Y")))
(global-set-key (kbd "C-c C-d") 'insert-long-date)

(defun insert-short-date ()
  "Insert a nicely formatted date string."
  (interactive)
   (insert (format-time-string "%d-%m-%y")))
;; (global-set-key (kbd "C-c C-d") 'insert-short-date)

;; My own macro to join current line with next.
;; join-line is an alias for `delete-indentation' in `simple.el'.
(defun my-join-lines () (interactive)
       (save-excursion (next-line) (join-line)) )
(global-set-key (kbd "M-j") 'my-join-lines)

(defun backward-kill-line (arg)
  "Kill chars backward until encountering the end of a line."
  (interactive "p") (kill-line 0) )
(global-set-key (kbd "C-M-k") 'backward-kill-line)
;; Note that C-M-backspace couldn't be assigned to.

;; ------------------------------------------------------------
;; To make end of sentences work as I want: single or double space OK.

(defun my-kill-sentence (&optional arg)
  "Kill from point to end of sentence.
With arg, repeat; negative arg -N means kill back to Nth start of sentence."
  (interactive "p")
  (progn
    (setq sentence-end-double-space nil)
;;    (kill-sentence arg)  ;; Next line is letter with backward-char added.
    (kill-region (point) (progn (forward-sentence arg) (backward-char) (point))))
    (setq sentence-end-double-space t)
)
(global-set-key (kbd "M-k") 'my-kill-sentence)
;; Next function works OK as is.
(global-set-key (kbd "C-S-k") 'backward-kill-sentence)

(defun my-fill-paragraph ()
  (interactive)
  (progn
    (setq sentence-end-double-space t)
    (fill-paragraph)
    (setq sentence-end-double-space nil)
))
(global-set-key (kbd "M-q") 'my-fill-paragraph)

;; ------------------------------------------------------------
;; http://endlessparentheses.com/better-backspace-during-isearch.html?source=rss
(defun mydelete ()
  "Delete the failed portion of the search string, or the last char if successful."
  (interactive)
  (with-isearch-suspended
      (setq isearch-new-string
            (substring
             isearch-string 0 (or (isearch-fail-pos) (1- (length isearch-string))))
            isearch-new-message
            (mapconcat 'isearch-text-char-description isearch-new-string ""))))
(define-key isearch-mode-map (kbd "<backspace>") 'mydelete)

;;------------------------




;; ---------------------------------------
;; (define-key ctl-x-map "\C-i" #'endless/ispell-word-then-abbrev)
;;(global-set-key (kbd "C-:") 'endless/ispell-word-then-abbrev)

;; http://endlessparentheses.com/ispell-and-abbrev-the-perfect-auto-correct.html
;;(defun endless/ispell-word-then-abbrev (p)
  "Call `ispell-word', then create an abbrev for it.
With prefix P, create local abbrev. Otherwise it will
be global.
If there's nothing wrong with the word at point, keep
looking for a typo until the beginning of buffer. You can
skip typos you don't want to fix with `SPC', and you can
abort completely with `C-g'."
;;  (interactive "P")
 ;; (let (bef aft)
 ;;   (save-excursion
  ;;    (while (if (setq bef (thing-at-point 'word))
                 ;; Word was corrected or used quit.
   ;;              (if (ispell-word nil 'quiet)
     ;;                nil ; End the loop.
                   ;; Also end if we reach `bob'.
     ;;              (not (bobp)))
               ;; If there's no word at point, keep looking
               ;; until `bob'.
     ;;          (not (bobp)))
     ;;   (backward-word))
     ;; (setq aft (thing-at-point 'word)))
    ;;(if (and aft bef (not (equal aft bef)))
    ;;    (let ((aft (downcase aft))
     ;;         (bef (downcase bef)))
     ;;     (define-abbrev
      ;;      (if p local-abbrev-table global-abbrev-table)
      ;;      bef aft)
      ;;    (message "\"%s\" now expands to \"%s\" %sally"
      ;;             bef aft (if p "loc" "glob")))
      ;;(user-error "No typo at or before point"))))

(setq save-abbrevs 'silently)
(setq-default abbrev-mode t)
;; ------------------------------------

;;  C-u 0 M-p shows a description of the change you made at each point.
(use-package goto-chg
  :ensure t
  :bind (("M-," . goto-last-change)
         ("M-." . goto-last-change-reverse)))

;;; * Other

;; http://pragmaticemacs.com/emacs/aligning-text/
(defun bjm/align-whitespace (start end)
  "Align columns by whitespace"
  (interactive "r")
  (align-regexp start end
                "\\(\\s-*\\)\\s-" 1 0 t))
;; -----------------------------------------

;; Next command seems to have same effect as align-current.
;; Useful for some other symbol?
(defun bjm/align-& (start end)
  "Align columns by ampersand"
  (interactive "r")
  (align-regexp start end
                "\\(\\s-*\\)&" 1 1 t))



;; http://www.emacswiki.org/emacs/LineCopyChar
(defun line-copy-char (&optional b)
 "Copy a character exactly below/above the point
  to the current point of the cursor (default is above)."
  (interactive "p")
    (let (p col s)
      (setq p (point))
      (setq col (current-column))
      (forward-line (if b -1 1))
      (move-to-column col)
      (setq s (buffer-substring (point) (+ (point) 1)))
      (goto-char p)
      (insert s)))
(define-key global-map [C-f4] 'line-copy-char)

; global-set-key (kbd "M-5") 'comment-or-uncomment-region)

; http://endlessparentheses.com/implementing-comment-line.html
(defun endless/comment-line-or-region (n)
  "Comment or uncomment current line and leave point after it.
With positive prefix, apply to N lines including current one.
With negative prefix, apply to -N lines above.
If region is active, apply to active region instead."
  (interactive "p")
  (if (use-region-p)
      (comment-or-uncomment-region
       (region-beginning) (region-end))
    (let ((range
           (list (line-beginning-position)
                 (goto-char (line-end-position n)))))
      (comment-or-uncomment-region
       (apply #'min range)
       (apply #'max range)))
    (forward-line 1)
    (back-to-indentation)))
(global-set-key (kbd "M-5") 'endless/comment-line-or-region)

;; ---------------------------------------------------
;; http://stackoverflow.com/questions/88399/how-do-i-duplicate-a-whole-line-in-emacs
;; (defun duplicate-line (&optional arg)
;;   "Duplicate it. With prefix ARG, duplicate ARG times."
;;   (interactive "p")
;;   (next-line
;;    (save-excursion
;;      (let ((beg (line-beginning-position))
;;            (end (line-end-position)))
;;        (copy-region-as-kill beg end)
;;        (dotimes (num arg arg)
;;          (end-of-line) (newline)
;;          (yank))))))

;; Try this one instead - doesn't use kill buffer: better?
;; https://github.com/jwiegley/dot-emacs/blob/master/init.el
(defun duplicate-line ()
  "Duplicate the line containing point."
  (interactive)
  (save-excursion
    (let (line-text)
      (goto-char (line-beginning-position))
      (let ((beg (point)))
        (goto-char (line-end-position))
        (setq line-text (buffer-substring beg (point))))
      (if (eobp)
          (insert ?\n)
        (forward-line))
      (open-line 1)
      (insert line-text))))

(global-set-key [f4] `duplicate-line)
;; ---------------------------------------------------

(defun transpose-chars-forward ()
   (interactive)
   (forward-char)
   (transpose-chars 1)
   (backward-char))
(defun transpose-chars-backward ()
   (interactive)
   (transpose-chars 1)
   (backward-char 2))
;;(global-set-key [f11] 'transpose-chars-forward)
;;(global-set-key [f12] 'transpose-chars-backward)
;; Note that f12 is different from C-t, which moves point forwards.

;; NB: find-file used. load-file is only for .el files.
;;(global-set-key [C-f1]
;;  '(lambda () (interactive) (find-file "~/Dropbox/org/emacs.org")))
;;(global-set-key [M-f1]
;;  '(lambda () (interactive) (find-file "~/Dropbox/org/todo.org")))
;;(global-set-key [S-f1]
;;  '(lambda () (interactive) (find-file "~/Dropbox/.emacs")))
;;(global-set-key [f1]  'delete-other-windows)
;;(global-set-key [C-S-f1]
;;  '(lambda () (interactive) (find-file "~/Dropbox/org/tex.org")))
;;(global-set-key [S-M-f1]
;;  '(lambda () (interactive) (find-file "~/Dropbox/org/blog.org")))
;;(global-set-key [C-M-f1]
 ;; '(lambda () (interactive) (find-file "~/Dropbox/org/org.org")))

; ----------------------------------------------------------
;; Disable prompt asking you if you want to kill a
;; buffer with a live process attached to it.
;; http://stackoverflow.com/questions/268088/how-to-remove-the-prompt-for-killing-emacsclient-buffers
;; (remove-hook 'kill-buffer-query-functions
;'server-kill-buffer-query-function)

;; For quitting file edited from server (e.g., Thunderbird).
;; (global-set-key (kbd "C-x t") 'server-edit)

; Trying this instead, from comment at
; https://nickhigham.wordpress.com/2015/06/18/my-dot-emacs.

;;(defun server-edit-or-close ()
;;"Saves and calls `server-edit’, if opened by server, or kills buffer."
;;(interactive)
;;(save-buffer)
;;(if server-buffer-clients
;(server-edit)
;;(kill-this-buffer)))
;;(global-set-key (kbd "C-x t") 'server-edit-or-close)

; ----------------------------------------------------------

;; More convenient ways to get to beginning and end of file.
(global-set-key [\C-kp-prior]   'beginning-of-buffer)  ; numpad Pgup
(global-set-key [\C-kp-next]    'end-of-buffer)        ; numpad PgDn

(global-set-key [\C-\M-kp-prior] 'beginning-of-buffer-other-window)
(global-set-key [\C-\M-kp-next]  'end-of-buffer-other-window)

(global-set-key [\C-\S-kp-prior]  'scroll-other-window-down)
(global-set-key [\C-\S-kp-next]   'scroll-other-window)

(if (system-is-mac)
    (progn
    (global-set-key (kbd "s-<up>")    'scroll-other-window-down)
    (global-set-key (kbd "s-<down>")  'scroll-other-window)
    ;; s = Cmd.  Want to set M-s-h but that doesn't work.
    (global-set-key (kbd "s-h")       'ns-do-hide-others)
))

;; Move to top left and bottom left of window.
(global-set-key [C-kp-home]
   '(lambda () (interactive) (move-to-window-line 0)))
(global-set-key [C-kp-end]
   '(lambda () (interactive) (move-to-window-line -1)))

;; For Macbook Pro, which has no insert key.
;; http://lists.gnu.org/archive/html/help-gnu-emacs/2006-07/msg00220.html
(global-set-key (kbd "C-c i") (function overwrite-mode))

(global-set-key [M-f11] 'quoted-insert) ; I use C-q for scrolling.

;; This handles cursor keys in cluster, but not numerical keypad.
;(global-set-key "\M-[1;5C"    'forward-to-word) ; Ctrl+right => forward word
;(global-set-key "\M-[1;5D"    'backward-word)   ; Ctrl+left  => back
;; (global-set-key [\C-kp-right] 'forward-to-word) ; keypad cursor key
;; (global-set-key [\C-kp-left]  'backward-word)   ; keypad cursor key

;; -------------------------------------------------
;; Commented out to see if cures yasnippet bug
;; Prefer not to skip over special chars:
;; http://stackoverflow.com/questions/3931837/modifying-emacs-forward-word-backward-ward-behavior-to-be-like-in-vi-vim
(setq viper-mode nil)
(require 'viper)
;; (global-set-key [\C-kp-right] 'viper-forward-word)
;; (global-set-key [\C-kp-left]  'viper-backward-word)
;; Trying "delimited by white characters" versions.
(global-set-key [\C-kp-right] 'viper-forward-Word)
(global-set-key [\C-kp-left]  'viper-backward-Word)

;; Needed for Mac.  On Windows this is for middle cluster.
(global-set-key [C-right] 'viper-forward-Word)  ; keypad cursor key
(global-set-key [C-left]  'viper-backward-Word) ; keypad cursor key
;; -------------------------------------------------

(defun my-transpose-word ()
  (interactive)
; (viper-forward-Word) (viper-backward-Word)  ; Not sure if need Viper.
  (forward-word) (backward-word)
  (forward-char) (transpose-words 1) (backward-word) )
(global-set-key (kbd "M-t") 'my-transpose-word)

;; -------------------------
;; Bubble lines up and down: http://www.emacswiki.org/emacs/MoveLine
(defun move-line (n)
  "Move the current line up or down by N lines."
  (interactive "p")
  (setq col (current-column))
  (beginning-of-line) (setq start (point))
  (end-of-line) (forward-char) (setq end (point))
  (let ((line-text (delete-and-extract-region start end)))
    (forward-line n)
    (insert line-text)
    ;; restore point to original column in moved line
    (forward-line -1)
    (forward-char col)))

(defun move-line-up (n)
  "Move the current line up by N lines."
  (interactive "p")
  (move-line (if (null n) -1 (- n))))

(defun move-line-down (n)
  "Move the current line down by N lines."
  (interactive "p")
  (move-line (if (null n) 1 n)))

(global-set-key (kbd "M-<up>")   'move-line-up)
(global-set-key (kbd "M-<down>") 'move-line-down)
;; -------------------------

;; Jump to matching parenthesis.  http://www.crsr.net/Notes/Emacs.html
;; http://emacs-fu.blogspot.co.uk/2009/01/balancing-your-parentheses.html
(defun goto-match-paren (arg)
  "Go to the matching parenthesis if on parenthesis, otherwise insert
the character typed."
  (interactive "p")
  (cond ((looking-at "\\s\(") (forward-list 1) (backward-char 1))
    ((looking-at "\\s\)") (forward-char 1) (backward-list 1))
;;    (t                    (self-insert-command (or arg 1))) ))
    (t                    ( )) ))
(global-set-key (kbd "M-=") `goto-match-paren)
;; NJH modified to do nothing if not on paren.

;; http://www.masteringemacs.org/articles/2011/08/04/full-text-searching-info-mode-apropos/#comments
;; Custom 'apropos' key bindings
(global-set-key (kbd "C-h C-a") 'Apropos-Prefix)
(define-prefix-command 'Apropos-Prefix nil "Apropos (a,d,f,i,l,v,C-v)")
(define-key Apropos-Prefix (kbd "a")   'apropos)
(define-key Apropos-Prefix (kbd "C-a") 'apropos)
(define-key Apropos-Prefix (kbd "d")   'apropos-documentation)
(define-key Apropos-Prefix (kbd "f")   'apropos-command)
(define-key Apropos-Prefix (kbd "c")   'apropos-command)
(define-key Apropos-Prefix (kbd "i")   'info-apropos)
(define-key Apropos-Prefix (kbd "l")   'apropos-library)
(define-key Apropos-Prefix (kbd "v")   'apropos-variable)
(define-key Apropos-Prefix (kbd "C-v") 'apropos-value)

;; ----- Modes
;; Make text mode the default.
(setq default-major-mode 'text-mode)

;; Turn on auto-fill mode for all text and org buffers.
(add-hook 'text-mode-hook 'turn-on-auto-fill)
(add-hook 'org-mode-hook 'turn-on-auto-fill)

;; Thunderbird email buffers.
(add-to-list 'auto-mode-alist '("\\.eml$" . mail-mode))

(use-package magit
  :defer t
 :diminish magit-auto-revert-mode

 :bind ("C-M-g" . magit-status)
  :preface

 :init
 (add-hook 'magit-mode-hook 'hl-line-mode)  ; Hilite current line.

  :config
  (setq magit-commit-all-when-nothing-staged t)

   full screen magit-status
  ;; http://whattheemacsd.com/setup-magit.el-01.html
  (defadvice magit-status (around magit-fullscreen activate)
   (window-configuration-to-register :magit-fullscreen)
  ;;  ad-do-it
   (delete-other-windows))
   (defun magit-quit-session ()
     "Restores the previous window configuration and kills the magit buffer"
      (interactive)
      (kill-buffer)
      (jump-to-register :magit-fullscreen))

     (bind-key "q" 'magit-quit-session magit-status-mode-map)
     (define-key magit-status-mode-map (kbd "q") 'magit-quit-session)

 )

;; (add-to-list 'load-path "~/Dropbox/elisp/magit-master")
;; (autoload 'magit-status "magit" nil t)
;; (require 'magit)
;; (global-set-key (kbd "C-M-g") 'magit-status)
;; (setq magit-commit-all-when-nothing-staged t)

;; ;; full screen magit-status
;; ;; http://whattheemacsd.com/setup-magit.el-01.html
   (defadvice magit-status (around magit-fullscreen activate)
    (window-configuration-to-register :magit-fullscreen)
;;   ad-do-it
    (delete-other-windows))
   (defun magit-quit-session ()
    (interactive)
    (kill-buffer)
    (jump-to-register :magit-fullscreen))
 ; -----------------------------------------------------------------------





;; -----------------------------
;; Tidy (clean) up non-ASCII characters

;; I used the first and second of these:
;; http://ergoemacs.org/emacs/elisp_replace_string_region.html
;; http://www.emacswiki.org/emacs/ReplaceGarbageChars
;; http://blog.gleitzman.com/post/35416335505/hunting-for-unicode-in-emacs
;; http://tonyballantyne.com/tech/category/emacs/emacs-lisp/

(defun tidy (begin end)
  "Replace non-ASCII characters in region, or buffer if no region."
  (interactive "r")
  (save-excursion(save-restriction

    ;; Adapted from narrow-or-widen-dwim, so as to use buffer if no region.
    (cond ( (region-active-p)
            (narrow-to-region (region-beginning) (region-end)) ))

    (goto-char (point-min))
    (while (search-forward "“" nil t) (replace-match "\"" nil t))

    (goto-char (point-min))
    (while (search-forward "”" nil t) (replace-match "\"" nil t))

   (goto-char (point-min))
    (while (search-forward "’" nil t) (replace-match "'" nil t))

   (goto-char (point-min))
    (while (search-forward "‘" nil t) (replace-match "'" nil t))

   (goto-char (point-min))
    (while (search-forward "…" nil t) (replace-match "..." nil t))

   (goto-char (point-min))
    (while (search-forward "–" nil t) (replace-match "-" nil t))

   (goto-char (point-min))
    (while (search-forward "—" nil t) (replace-match "-" nil t))

   (goto-char (point-min))
   (while (search-forward "−" nil t) (replace-match "-" nil t))

    ;; (goto-char (point-min))
    ;; (while (search-forward "" nil t) (replace-match "fi" nil t))

   (replace-string "" "`" nil (point-min) (point-max))  ; opening single quote
   (replace-string "" "'" nil (point-min) (point-max))  ; closing single quote
   (replace-string "" "\"" nil (point-min) (point-max))
   (replace-string "" "\"" nil (point-min) (point-max))
   (replace-string "" "-" nil (point-min) (point-max))
;; Next line deleted as it puts everything on one line when applied to
;; whole file!
;;    (replace-string "
;; " "" nil (point-min) (point-max))
)))

;; http://stackoverflow.com/questions/730751/hiding-m-in-emacs
;; Get rid of "^M" displayed in file (Emacs will have set Unix mode).

(defun dos2unix ()
  "Replace DOS eolns CR LF with Unix eolns CR"
  (interactive)
    (goto-char (point-min))
      (while (search-forward (string ?\C-m) nil t) (replace-match "")))

;; For making comma-separated list of keywords from list of words.
(defun make-keywords (begin end)
  "Replace non-ASCII characters in region, or buffer if no region."
    ;; Adapted from tidy.
  (interactive "r")
  (save-restriction

    (cond ( (region-active-p)
            (narrow-to-region (region-beginning) (region-end)) ))

    (goto-char (point-min))
    (while (search-forward ", " nil t) (replace-match " " nil t))
    (goto-char (point-min))
    (while (search-forward ". " nil t) (replace-match " " nil t))
    (goto-char (point-min))
    (while (search-forward " " nil t) (replace-match ", " nil t))
))


 
	
	
;;(use-package ess-site  ;not include melpa
;;  :commands R)

;; Single space after period denotes end of sentence.
(setq sentence-end-double-space nil)

;; http://emacswiki.org/emacs/UnfillParagraph
;;; Stefan Monnier <foo at acm.org>. It is the opposite of fill-paragraph
(defun unfill-paragraph ()
  "Takes a multi-line paragraph and makes it into a single line of text."
  (interactive)
  (let ((fill-column (point-max)))
    (fill-paragraph nil)))
(global-set-key (kbd "<S-f7>") 'unfill-paragraph)

(defun unfill-region ()
  "Unfill a region, i.e., make text in that region not wrap."
   (interactive)
   (let ((fill-column (point-max)))
   (fill-region (region-beginning) (region-end) nil)))

(defun fill-to-end-of-buffer ()
"Fill to end of buffer."
(interactive)
(save-excursion
(delete-trailing-whitespace)
(fill-region (point) (point-max) nil)
(untabify (point) (point-max))))






	
 
;; --------------------------------------------------------
;; 


;; Summing a column
;; http://www.emacswiki.org/emacs/RectangleAdd (renamed to *sum).
;; Note: It seems to need a space after each number.

(defun rectangle-sum (start end)
  "Add all the lines in the region-rectangle and put the result in the
   kill ring."
  (interactive "r")
  (let ((sum 0))
    (mapc (lambda (line)
            (setq sum (+ sum (rectangle-sum-make-number line))))
          (extract-rectangle start end))
    (kill-new (number-to-string sum))
    (message "%s" sum)))

(defun rectangle-sum-make-number (n)
  "Turn a string into a number, being tolerant of commas and even other
   'junk'."
(while (string-match "[^0-9.]" n)
  (setq n (replace-match "" nil nil n)))
  (string-to-number n))




;;; * Local Variables

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;;https://github.com/jwiegley/dot-emacs/blob/80f70631c03b2dd4f49741478453eaf1a2fe469b/init.el 
(use-package pdf-tools
  :magic ("%PDF" . pdf-view-mode)
  :config
  (dolist
      (pkg
       '(pdf-annot pdf-cache pdf-dev pdf-history pdf-info pdf-isearch
                   pdf-links pdf-misc pdf-occur pdf-outline pdf-sync
                   pdf-util pdf-view pdf-virtual))
    (require pkg))
  (pdf-tools-install))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ace-isearch-function (quote ace-jump-word-mode))
 '(ace-isearch-input-length 6)
 '(ace-isearch-jump-delay 0.25)
 '(ace-isearch-use-jump (quote printing-char))
 '(package-selected-packages
   (quote
    (ivy-dired-history ivy-bibtex ivy ox-latex yasnippet wttrin wrap-region which-key wgrep-ag wc-mode use-package undo-tree try switch-window swap-buffers smex smartparens shrink-whitespace shell-pop ripgrep phi-search-mc pdf-tools ox-pandoc mmm-mode mc-extras matlab-mode markdown-mode magit macrostep latex-extra imenu-anywhere ibuffer-vc     guide-key goto-chg git-timemachine expand-region elfeed dired-toggle dired-quick-sort diminish deft define-word counsel company cnfonts clippy char-menu bug-hunter browse-kill-ring avy-zap auto-complete auto-compile auctex-latexmk anzu ace-window ace-link ace-jump-zap ace-jump-buffer ace-isearch))))
 ;; Local Variables:
;; eval: (orgstruct-mode 1).
;; orgstruct-heading-prefix-regexp: ";;; ";
; End:
