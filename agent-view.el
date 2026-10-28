;;; agent-view.el -*- lexical-binding: t; -*-

;; Declared here: these come from agent-shell and agent-desk, loaded by their
;; own packages.
(defvar agent-shell-mode-map)
(defvar agent-shell-busy-submit-default-function)
(defvar agent-shell-busy-submit-override-function)
(defvar agent-shell-chat-label-function)
(defvar agent-desk--thread-id)
(declare-function agent-shell-config-options "agent-shell")
(declare-function agent-shell-busy-submit-steer "agent-shell-prompt-queue")
(declare-function agent-shell-busy-submit-queue "agent-shell-prompt-queue")
(declare-function mixed-pitch-mode "mixed-pitch")
(declare-function map-elt "map")
(declare-function map-nested-elt "map")
(declare-function agent-shell-subscribe-to "agent-shell")
(declare-function agent-shell--context-usage-indicator "agent-shell-usage")
(declare-function agent-desk-store-get-thread "agent-desk-store")
(declare-function agent-desk-account-by-id "agent-desk-accounts")
(declare-function agent-desk-icon-letter "agent-desk-icons")
(declare-function agent-desk-icon-color "agent-desk-icons")

;;; Chat look

(defvar my/agent-prose-height 0.9
  "Height of agent chat prose, as a fraction of the default face.")

(defconst my/agent-fixed-pitch-faces
  '(agent-shell-markdown-inline-code
    agent-shell-markdown-source-block
    agent-shell-markdown-source-block-language
    agent-shell-markdown-table
    agent-shell-markdown-table-border
    agent-shell-markdown-table-header
    agent-shell-markdown-table-zebra)
  "Chat faces that stay fixed-pitch: code, tables and their borders.")

(defvar my/agent-prose-families
  '("Inter" "Inter Variable" "SF Pro Text" "Helvetica Neue")
  "Proportional fonts tried in order for chat prose.
Inter (brew install --cask font-inter) is wide and open, the closest free
match to Claude's own sans.  A font installed while Emacs runs may show up
only as \"Inter Variable\" until a restart.")

(defun my/agent-prose-family ()
  "The first installed font of `my/agent-prose-families'."
  (or (and (display-graphic-p)
           (seq-find (lambda (family) (find-font (font-spec :family family)))
                     my/agent-prose-families))
      "Helvetica Neue"))

(defun my/agent-header-hover ()
  "Make hovering the chat header a subtle lift instead of the theme's violet.
The header's model and mode text is violet too, and vanished under it."
  (let ((background (or (face-background 'region nil t)
                        (face-background 'hl-line nil t))))
    (dolist (face '(mode-line-highlight header-line-highlight))
      (face-remap-add-relative face :background background :foreground 'unspecified
                               :box nil :inverse-video nil))))

(defface my/agent-fold-chevron
  '((t :inherit shadow :family "Symbols Nerd Font Mono" :height 1.0))
  "The chat's fold arrows, small and dim like treemacs' chevrons.")

(defun my/agent-fold-chevrons ()
  "Draw agent-shell's ▶/▼ fold arrows as treemacs' octicon chevrons.
agent-shell inserts and later searches for the literal triangles, so only
their display changes, through the buffer's display table."
  (let ((table (or buffer-display-table (make-display-table))))
    (pcase-dolist (`(,arrow . ,chevron) '((?▶ . #xF460) (?▼ . #xF47C)))
      (aset table arrow (vector (make-glyph-code chevron 'my/agent-fold-chevron))))
    (setq buffer-display-table table)))

(defun my/agent-prompt-cursor ()
  "Show the chat's cursor only in the prompt, where typing goes.
In the history above, clicks and drags still move point and select text."
  (setq cursor-type (and (comint-after-pmark-p) (default-value 'cursor-type))))

(defun my/agent-shell-prose ()
  "Give a chat buffer proportional prose; code and tables stay fixed-pitch."
  (my/agent-header-hover)
  (my/agent-fold-chevrons)
  (add-hook 'post-command-hook #'my/agent-prompt-cursor nil t)
  (mixed-pitch-mode 1)
  (face-remap-add-relative 'variable-pitch
                           :family (my/agent-prose-family)
                           :height my/agent-prose-height))

(defun my/agent-prose-after-solaire ()
  "Put mixed-pitch's proportional font back in front of solaire's remap.
Solaire turns on after the mode hooks; its face inherits `default', so as
the newer remap it would bring the monospace font back over the prose.
Attribute lists (mixed-pitch's) go first, face names (solaire's) after."
  (when-let* (((derived-mode-p 'agent-shell-mode))
              (specs (cdr (assq 'default face-remapping-alist))))
    (setq-local face-remapping-alist
                (cons (cons 'default (append (seq-filter #'consp specs)
                                             (seq-remove #'consp specs)))
                      (assq-delete-all 'default (copy-sequence face-remapping-alist))))))

(add-hook 'solaire-mode-hook #'my/agent-prose-after-solaire)

(use-package! mixed-pitch
  :commands mixed-pitch-mode
  :config
  (dolist (face my/agent-fixed-pitch-faces)
    (add-to-list 'mixed-pitch-fixed-pitch-faces face)))

(with-eval-after-load 'agent-shell
  (add-hook 'agent-shell-mode-hook #'my/agent-shell-prose)
  ;; comint's menus carry nothing a chat needs.
  (dolist (entry '(inout signals completion))
    (define-key agent-shell-mode-map (vector 'menu-bar entry) 'undefined))
  ;; RET steers a running turn; Option+RET queues it.
  (setq agent-shell-busy-submit-default-function #'agent-shell-busy-submit-steer
        agent-shell-busy-submit-override-function #'agent-shell-busy-submit-queue))

;;; Chat labels

(defvar-local my/agent-chat-account-cache nil
  "A (THREAD-ID . ACCOUNT) pair: the account last looked up for this chat.")

(defun my/agent-chat-account ()
  "The account of the chat in the current buffer, or nil.
It is looked up once per thread: the modeline asks on every redisplay."
  (when (and (bound-and-true-p agent-desk--thread-id)
             (fboundp 'agent-desk-store-get-thread))
    (if (eql (car my/agent-chat-account-cache) agent-desk--thread-id)
        (cdr my/agent-chat-account-cache)
      (let ((account (when-let ((row (agent-desk-store-get-thread agent-desk--thread-id)))
                       (agent-desk-account-by-id (plist-get row :account-id)))))
        (setq my/agent-chat-account-cache (cons agent-desk--thread-id account))
        account))))

(defun my/agent-chat-label (label)
  "Draw a chat LABEL: the user's name bold, the agent's in its account colour.
The agent's badge is a letter in the account colour, as in the sidebar."
  (let* ((user (eq (map-elt label :role) 'user))
         (text (map-elt label :text))
         (account (and (not user) (my/agent-chat-account)))
         (color (and account (fboundp 'agent-desk-icon-color)
                     (agent-desk-icon-color account))))
    (if (and account color)
        (concat (propertize (format " %s " (agent-desk-icon-letter account))
                            'face `(:background ,color :foreground "#ffffff" :weight bold))
                (propertize (format " %s" text)
                            'face `(:foreground ,color :weight bold)))
      (propertize (format " %s " text)
                  'face (if user
                            '(:weight bold :inherit font-lock-keyword-face)
                          '(:weight bold :inherit font-lock-function-name-face))))))

(with-eval-after-load 'agent-shell-chat-mode
  (setq agent-shell-chat-label-function #'my/agent-chat-label))

;;; Keys for the chat

;;; Terminal under the chat

(defvar my/agent-terminal-height 0.3
  "Height of the terminal under the chat, as a fraction of the chat window.")

(require 'eshell nil t)

(defun my/agent-terminal-buffer (directory)
  "The terminal buffer for DIRECTORY, started there when it does not exist yet."
  (let* ((dir (file-name-as-directory (expand-file-name directory)))
         (name (format "*agent-terminal %s*" (abbreviate-file-name dir))))
    (or (get-buffer name)
        (let ((default-directory dir))
          (if (fboundp 'vterm-mode)
              (with-current-buffer (get-buffer-create name)
                (vterm-mode)
                (current-buffer))
            (let ((eshell-buffer-name name))
              (eshell t)))))))

(defun my/agent-chat-window ()
  "The window to split for the terminal: the selected one, unless it is a
dedicated side panel, which is never split; then the largest ordinary window."
  (let ((window (selected-window)))
    (if (window-dedicated-p window)
        (or (get-largest-window nil nil t) window)
      window)))

(defun my/agent-toggle-terminal ()
  "Open or close the project terminal under the chat window.
It starts in the chat's directory and is reused for that project."
  (interactive)
  (let* ((buffer (my/agent-terminal-buffer default-directory))
         (shown (get-buffer-window buffer)))
    (if shown
        (delete-window shown)
      (let* ((chat (my/agent-chat-window))
             (below (split-window chat (round (* (- 1 my/agent-terminal-height)
                                                 (window-total-height chat)))
                                  'below)))
        (set-window-buffer below buffer)
        (select-window below)))))

(global-set-key (kbd (my/platform-keybinding "`")) #'my/agent-toggle-terminal)
(with-eval-after-load 'agent-shell
  (define-key agent-shell-mode-map (kbd "C-c `") #'my/agent-toggle-terminal))

;;; Cheat sheet

(defvar my/agent-cheatsheet-pdf
  (expand-file-name "docs/agent-shell-cheatsheet.pdf" doom-user-dir)
  "The agent-shell cheat sheet as a PDF.")

(defun my/agent-cheatsheet ()
  "Open the agent-shell cheat sheet PDF."
  (interactive)
  (if (file-exists-p my/agent-cheatsheet-pdf)
      (if (eq my/platform 'macos)
          (start-process "cheatsheet" nil "open" my/agent-cheatsheet-pdf)
        (browse-url-of-file my/agent-cheatsheet-pdf))
    (user-error "No cheat sheet at %s" my/agent-cheatsheet-pdf)))

;;; One modeline, with the chat's account and model

(defvar my/agent-usage (make-hash-table :test 'equal)
  "Per account id, an alist of rate limit type to the latest report of it.
Each report is the agent's `_claude/rateLimit' metadata: utilization,
resetsAt, rateLimitType and status.")

(defun my/agent-usage-subscribe ()
  "Follow the agent's rate limit reports for the chat in the current buffer."
  (when (fboundp 'agent-shell-subscribe-to)
    (let ((buffer (current-buffer)))
      (agent-shell-subscribe-to
       :shell-buffer buffer
       :event 'usage-update
       :on-event
       (lambda (event)
         (when (buffer-live-p buffer)
           (let ((limit (map-nested-elt event '(:data :meta _claude/rateLimit))))
             (with-current-buffer buffer
               (when-let ((account (my/agent-chat-account)))
                 (when limit
                   (my/agent-usage-record (format "%s" (plist-get account :id))
                                          limit)))))))))))

(defun my/agent-usage-record (account-id limit)
  "Keep LIMIT as ACCOUNT-ID's latest report for its rate limit type.
A report also carries every window in `unifiedWindows' (the 5-hour one
arrives inside a 7-day report); each is kept under its own type."
  (let* ((type (format "%s" (or (map-elt limit 'rateLimitType) "five_hour")))
         (reports (gethash account-id my/agent-usage)))
    (dolist (window (ignore-errors (map-elt limit 'unifiedWindows)))
      (let ((name (format "%s" (car window))))
        (unless (equal name type)
          (setf (alist-get name reports nil nil #'equal)
                (cons (cons 'rateLimitType name) (cdr window))))))
    (setf (alist-get type reports nil nil #'equal) limit)
    (puthash account-id reports my/agent-usage)))

(defconst my/agent-limit-names
  '(("five_hour" . "5h") ("seven_day" . "7d") ("seven_day_opus" . "7d Opus")
    ("seven_day_sonnet" . "7d Sonnet") ("overage" . "extra"))
  "Short modeline names of the agent's rate limit types.")

(defun my/agent-limit-percent (limit)
  "LIMIT's utilization in percent, or nil.  The agent may send 0-1 or 0-100."
  (let ((utilization (ignore-errors (map-elt limit 'utilization))))
    (when (numberp utilization)
      (round (if (<= utilization 1) (* 100 utilization) utilization)))))

(defun my/agent-limit-face (limit percent)
  "The face for LIMIT at PERCENT: red when rejected, orange when warned or high."
  (let ((status (format "%s" (or (ignore-errors (map-elt limit 'status)) ""))))
    (cond ((equal status "rejected") 'error)
          ((or (equal status "allowed_warning") (and percent (>= percent 80))) 'warning)
          (t 'doom-modeline-info))))

(defun my/agent-limit-reset (limit)
  "When LIMIT resets, as \"↻18:00\" today or \"↻Mon 03:00\" later, or nil."
  (let ((resets (ignore-errors (map-elt limit 'resetsAt))))
    (when (numberp resets)
      ;; The SDK sends seconds; milliseconds would be far in the future.
      (let ((time (if (> resets 1e11) (/ resets 1000.0) resets)))
        (concat "↻" (format-time-string
                     (if (< (- time (float-time)) 86400) "%H:%M" "%a %H:%M")
                     time))))))

(defun my/agent-usage-label (account)
  "ACCOUNT's reported rate limits, as \"5h 34% ↻18:00  7d 51%\", or nil."
  (when-let ((reports (gethash (format "%s" (plist-get account :id)) my/agent-usage)))
    (mapconcat
     (lambda (entry)
       (let* ((limit (cdr entry))
              (percent (my/agent-limit-percent limit))
              (name (or (alist-get (car entry) my/agent-limit-names nil nil #'equal)
                        (car entry))))
         (propertize (string-join (delq nil (list name
                                                  (and percent (format "%d%%" percent))
                                                  (my/agent-limit-reset limit)))
                                  " ")
                     'face (my/agent-limit-face limit percent))))
     (sort (copy-sequence reports)
           (lambda (a b) (string< (car a) (car b))))
     "  ")))

(defun my/agent-chat-model-label ()
  "The model the current chat runs, from its session options, or nil."
  (when (derived-mode-p 'agent-shell-mode)
    (when-let* ((options (condition-case nil (agent-shell-config-options) (error nil)))
                (model (seq-find (lambda (option)
                                   (equal (map-elt option :category) "model"))
                                 options))
                (current (map-elt model :current-value)))
      (or (map-elt (seq-find (lambda (choice) (equal (map-elt choice :value) current))
                             (map-elt model :options))
                   :name)
          current))))

(with-eval-after-load 'doom-modeline
  (doom-modeline-def-segment agent-chat
    "The chat's account and model, shown in the centre of the modeline."
    (when-let ((account (my/agent-chat-account)))
      (let ((model (my/agent-chat-model-label))
            (limit (my/agent-usage-label account)))
        (concat (propertize (format " %s " (agent-desk-icon-letter account))
                            'face `(:background ,(agent-desk-icon-color account)
                                    :foreground "#ffffff" :weight bold))
                (when model (format "  %s" model))
                ;; agent-shell's own "23k/1m (2%)", escaped for the modeline.
                (when-let ((context (ignore-errors (agent-shell--context-usage-indicator))))
                  (concat "  " context))
                ;; The modeline reads % as a format code: double it.
                (when limit (concat "  " (string-replace "%" "%%" limit)))))))
  (doom-modeline-def-modeline 'agent-chat
    '(bar window-number modals buffer-info)
    '(agent-chat misc-info major-mode process)))

(add-hook 'agent-shell-mode-hook
          (lambda ()
            (my/agent-usage-subscribe)
            (when (fboundp 'doom-modeline-set-modeline)
              (doom-modeline-set-modeline 'agent-chat))))

;; The desk's side panels show no modeline of their own; the chat's carries the state.
(with-eval-after-load 'agent-desk-ui
  (advice-add 'agent-desk-ui-display-side :filter-return
              (lambda (window)
                (when (window-live-p window)
                  (set-window-parameter window 'mode-line-format 'none))
                window)))

(provide 'agent-view)
;;; agent-view.el ends here
