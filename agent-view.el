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

(defun my/agent-prose-family ()
  "The proportional font for chat prose: Inter when installed, else SF Pro Text."
  (if (and (display-graphic-p) (find-font (font-spec :family "Inter")))
      "Inter"
    "SF Pro Text"))

(defun my/agent-shell-prose ()
  "Give a chat buffer proportional prose; code and tables stay fixed-pitch."
  (mixed-pitch-mode 1)
  (face-remap-add-relative 'variable-pitch
                           :family (my/agent-prose-family)
                           :height my/agent-prose-height))

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

(defun my/agent-chat-account ()
  "The account of the chat in the current buffer, or nil."
  (when (and (bound-and-true-p agent-desk--thread-id)
             (fboundp 'agent-desk-store-get-thread))
    (when-let ((row (agent-desk-store-get-thread agent-desk--thread-id)))
      (agent-desk-account-by-id (plist-get row :account-id)))))

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

(defun my/agent-toggle-terminal ()
  "Open or close the project terminal under the chat window.
It starts in the chat's directory and is reused for that project."
  (interactive)
  (let* ((buffer (my/agent-terminal-buffer default-directory))
         (shown (get-buffer-window buffer)))
    (if shown
        (delete-window shown)
      (let* ((chat (or (get-buffer-window (current-buffer)) (selected-window)))
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
      (let ((model (my/agent-chat-model-label)))
        (concat (propertize (format " %s " (agent-desk-icon-letter account))
                            'face `(:background ,(agent-desk-icon-color account)
                                    :foreground "#ffffff" :weight bold))
                (when model (format "  %s" model))))))
  (doom-modeline-def-modeline 'agent-chat
    '(bar window-number modal buffer-info)
    '(agent-chat misc-info major-mode process)))

(add-hook 'agent-shell-mode-hook
          (lambda ()
            (when (fboundp 'doom-modeline-set-modeline)
              (doom-modeline-set-modeline 'agent-chat))))

;; The desk's side panels show no modeline of their own; the chat's carries the state.
(with-eval-after-load 'agent-desk-ui
  (advice-add 'agent-desk-ui-display-side :filter-return
              (lambda (window)
                (when (window-live-p window)
                  (set-window-parameter window 'mode-line-format 'none))
                window)))
