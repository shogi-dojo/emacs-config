;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;;; Platform detection

(defvar my/platform
  (cond
   ((eq system-type 'darwin) 'macos)
   ((eq system-type 'android) 'android)
   ((and (eq system-type 'gnu/linux)
         (or (getenv "TERMUX_VERSION")
             (file-directory-p "/data/data/com.termux")))
    'android)
   ((eq system-type 'gnu/linux) 'linux)
   ((eq system-type 'windows-nt) 'windows)
   (t 'linux))
  "Current platform: macos, linux, windows, or android.")

(defvar my/font-size 15
  "Default font size. Platform files override this before fonts are configured.")

(defvar my/font-family "JetBrainsMono Nerd Font"
  "Default monospace font family. Platform files may override it.")

(defvar my/cjk-font-family "Noto Sans JP"
  "Default CJK fallback font family. Platform files may override it.")

(defvar my/org-font-family "Sarasa Mono J"
  "Default font family for Org buffers. Platform files may override it.")

(defvar my/line-spacing 3
  "Default line spacing. Platform files can override this before display setup.")

(load! (format "platforms/%s" my/platform))

;;; Quit without confirmation

;; Emacs still asks about unsaved buffers and running processes.
(setq confirm-kill-emacs nil)

;;; Reload files changed by external tools

;; Refresh unmodified file buffers; auto-revert preserves unsaved edits.
;; Doom's own autorevert :config resets these on load, so set them after it.
(after! autorevert
  (setq auto-revert-interval 1
        auto-revert-use-notify t
        auto-revert-verbose nil
        auto-revert-check-vc-info t
        global-auto-revert-non-file-buffers t))
(global-auto-revert-mode 1)

;;; Appearance

(setq doom-theme 'doom-dracula
      doom-font (font-spec :family my/font-family :size my/font-size))

(add-hook 'after-setting-font-hook
          (lambda ()
            (let ((cjk-font (font-spec :family my/cjk-font-family))
                  (nerd-font (font-spec :family "Symbols Nerd Font Mono")))
              (set-fontset-font t 'han cjk-font)
              (set-fontset-font t 'kana cjk-font)
              (set-fontset-font t 'cjk-misc cjk-font)
              (set-fontset-font t '(#xf0000 . #xf9999) nerd-font))))

(add-hook 'org-mode-hook
          (lambda ()
            (setq-local face-remapping-alist
                        `((default :family ,my/org-font-family :height 210)))))

(setq display-line-numbers-type nil
      doom-scratch-initial-major-mode 'lisp-interaction-mode
      evil-emacs-state-cursor '("purple" bar)
      doom-modeline-icon t
      doom-modeline-major-mode-icon t
      doom-modeline-major-mode-color-icon t
      doom-modeline-lsp-icon t
      doom-modeline-time-icon t
      doom-modeline-time-live-icon t
      doom-modeline-time-analogue-clock t
      doom-modeline-vcs-max-length 30
      doom-modeline-buffer-file-name-style 'buffer-name)

(setq-default cursor-type 'bar
              line-spacing my/line-spacing)
(setq scroll-margin 0
      jit-lock-defer-time 0.05
      fast-but-imprecise-scrolling t
      redisplay-skip-fontification-on-input t
      vterm-max-scrollback 100000)
(blink-cursor-mode 1)
(when (fboundp 'context-menu-mode)
  (context-menu-mode 1))

;;; Tab bar

;; Sublime-like tabs: taller, padded, a UI font, a file-type icon, the
;; selected tab in the editor background and the rest in the bar colour.
(defvar my/tab-bar-font-families
  '("SF Pro Text" "SF Pro" "Helvetica Neue" "Inter" "Cantarell" "Noto Sans")
  "UI fonts tried in order for tab labels; the editor font is the fallback.")

(defvar my/tab-bar-named-icons
  '(("Agents" . (nerd-icons-mdicon "nf-md-robot_outline")))
  "Icons for renamed tabs, whose names are not buffer names.")

(defun my/tab-bar--pad (pixels)
  "Return a blank of PIXELS width."
  (propertize " " 'display `(space :width (,pixels))))

(defun my/tab-bar--tab-buffer (tab)
  "Return the buffer TAB shows, or nil."
  (if (eq (car tab) 'current-tab)
      (window-buffer (minibuffer-selected-window))
    (get-buffer (alist-get 'name tab))))

(defun my/tab-bar-tab-icon (tab)
  "Return the icon for TAB: a named icon, its buffer's icon, or a file."
  (let ((named (assoc (alist-get 'name tab) my/tab-bar-named-icons))
        (buffer (my/tab-bar--tab-buffer tab)))
    (cond (named (eval (cdr named) t))
          (buffer (with-current-buffer buffer (nerd-icons-icon-for-buffer)))
          (t (nerd-icons-faicon "nf-fa-file_o")))))

(defun my/tab-bar-format-icon (name tab _i)
  "Prefix NAME with padding and TAB's icon.
The padding is plain spaces: `tab-bar-auto-width' widens a tab by copying
its first character, and copies of a `display' space merge into one, so
a display-space first character would make it loop forever in redisplay."
  (concat "   "
          (if (require 'nerd-icons nil t)
              ;; A display space is safe here, away from the first character.
              (concat (or (ignore-errors (my/tab-bar-tab-icon tab)) "")
                      (my/tab-bar--pad 10))
            "")
          name))

(setq tab-bar-separator (my/tab-bar--pad 1)
      tab-bar-close-button-show t
      tab-bar-auto-width-min '((150) 14)
      tab-bar-auto-width-max '((280) 26)
      tab-bar-tab-name-format-functions
      '(my/tab-bar-format-icon
        tab-bar-tab-name-format-close-button
        tab-bar-tab-name-format-face))

;; The tab's right padding is a space after the close button.  It must
;; carry `close-tab' so auto-width still sees the button at the end.
;; Tab-bar reloads its buttons whenever the mode turns on, so add it then.
(defun my/tab-bar-pad-close-button (&rest _)
  "Append a clickable space to `tab-bar-close-button'."
  (unless (get-text-property 0 'my/padded tab-bar-close-button)
    (setq tab-bar-close-button
          (propertize (concat tab-bar-close-button
                              (propertize " " 'close-tab t))
                      'my/padded t))))

(advice-add 'tab-bar--load-buttons :after #'my/tab-bar-pad-close-button)

(defun my/tab-bar-apply-faces ()
  "Restyle the tab bar from the current theme's palette."
  (let ((bar (doom-color 'bg-alt))
        (active (doom-color 'bg))
        (family (seq-find (lambda (f) (find-font (font-spec :family f)))
                          my/tab-bar-font-families))
        (vertical '(1 . 8)))
    (set-face-attribute 'tab-bar nil
                        :family (or family 'unspecified) :height 1.0
                        :background bar :foreground (doom-color 'base5)
                        :box `(:line-width (1 . 2) :color ,bar))
    (set-face-attribute 'tab-bar-tab nil
                        :inherit 'tab-bar :background active
                        :foreground (doom-color 'fg) :weight 'semi-bold
                        :box `(:line-width ,vertical :color ,active))
    (set-face-attribute 'tab-bar-tab-inactive nil
                        :inherit 'tab-bar :background bar
                        :foreground (doom-color 'base6) :weight 'normal
                        :box `(:line-width ,vertical :color ,bar))))

(add-hook 'doom-load-theme-hook #'my/tab-bar-apply-faces)

;;; Behavior

(setq org-directory "~/org/"
      evil-default-state 'emacs
      select-enable-clipboard nil
      doom-leader-alt-key "M-SPC"
      doom-localleader-alt-key "M-SPC m")

(delete-selection-mode 1)
(global-subword-mode +1)
(super-save-mode +1)
(setq super-save-auto-save-when-idle t
      auto-save-default nil)

(when (eq my/platform 'android)
  (setq default-input-method "japanese"))

;;; Completion

(after! company
  (define-key company-active-map (kbd "<escape>") #'company-abort))

;;; Devil mode

(setq devil-lighter " \U0001F608"
      devil-prompt "\U0001F608 %t")
(global-devil-mode)

(when (eq my/platform 'macos)
  (define-key devil-mode-map (kbd "б") #'devil)
  (add-to-list 'devil-special-keys `("б б" . ,(devil-key-executor "б")))
  (setq devil-translations '(("б" . "C-")
                             (", ," . ",")
                             ("б б" . "б")
                             ("," . "C-"))))

;;; Find file across Treemacs projects

;; Build output and package stores that projects don't always gitignore,
;; plus images and audio, which are rarely opened by name.
;; Top-level notes/ is gitignored in some projects but holds agent notes,
;; so list it anyway; the ignores above still apply inside it.
(after! projectile
  (dolist (dir '("*node_modules" "*nimcache" "*.pnpm-store" "*.venv" "*__pycache__"))
    (add-to-list 'projectile-globally-ignored-directories dir))
  (dolist (suffix '(".webp" ".png" ".jpg" ".jpeg" ".svg" ".mp3" ".wav"))
    (add-to-list 'projectile-globally-ignored-file-suffixes suffix))
  (add-to-list 'projectile-globally-unignored-directories "notes"))

(defun my/treemacs-project-roots ()
  "Return (NAME . ROOT) for each project in the current Treemacs workspace.
The project containing the current buffer comes first."
  (when (require 'treemacs nil t)
    (let* ((here (and default-directory (expand-file-name default-directory)))
           (projects
            (mapcar (lambda (p)
                      (cons (treemacs-project->name p)
                            (file-name-as-directory
                             (expand-file-name (treemacs-project->path p)))))
                    (treemacs-workspace->projects (treemacs-current-workspace)))))
      (append (seq-filter (lambda (p) (and here (string-prefix-p (cdr p) here))) projects)
              (seq-remove (lambda (p) (and here (string-prefix-p (cdr p) here))) projects)))))

(defun my/find-file-in-treemacs-projects ()
  "Find a file in any project of the current Treemacs workspace.
Falls back to `projectile-find-file' when the workspace has no projects."
  (interactive)
  (let ((projects (my/treemacs-project-roots)))
    (if (null projects)
        (call-interactively #'projectile-find-file)
      (let* ((paths (make-hash-table :test #'equal))
             ;; Skip projectile's persistent cache so new files show up at once.
             (projectile-enable-caching nil)
             (candidates
              (cl-loop for (name . root) in projects
                       nconc (cl-loop for file in (projectile-project-files root)
                                      for candidate = (concat name "/" file)
                                      do (puthash candidate (expand-file-name file root) paths)
                                      collect candidate)))
             (choice (completing-read "Find file in projects: " candidates nil t)))
        (find-file (gethash choice paths))))))

;;; Key chords

(key-chord-mode +1)
(key-chord-define-global "jj" 'avy-goto-word-1)
(key-chord-define-global "jk" 'avy-goto-char)
(key-chord-define-global "jl" 'avy-goto-line)
(key-chord-define-global "xx" 'execute-extended-command)
(key-chord-define-global "kk" 'my/find-file-in-treemacs-projects)
(key-chord-define-global "ww" 'switch-to-buffer)
(key-chord-define-global "JJ" 'crux-switch-to-previous-buffer)
(key-chord-define-global ";;" 'repeat)

(when (eq my/platform 'macos)
  (defvar my/multibyte-chords
    '((?ц . switch-to-buffer)
      (?л . my/find-file-in-treemacs-projects)
      (?ч . execute-extended-command))
    "Alist of (CHAR . COMMAND) for double-tap multibyte key chords.")

  (defvar my/multibyte-chord--last-char nil)
  (defvar my/multibyte-chord--last-time nil)

  (defun my/multibyte-chord-detect ()
    "Detect double-tap of multibyte characters and run the bound command."
    (let* ((char last-command-event)
           (now (float-time))
           (cmd (alist-get char my/multibyte-chords)))
      (if (and cmd
               my/multibyte-chord--last-char
               (eq char my/multibyte-chord--last-char)
               my/multibyte-chord--last-time
               (< (- now my/multibyte-chord--last-time) key-chord-one-key-delay))
          (progn
            (delete-char -1)
            (delete-char -1)
            (setq my/multibyte-chord--last-char nil
                  my/multibyte-chord--last-time nil)
            (call-interactively cmd))
        (setq my/multibyte-chord--last-char char
              my/multibyte-chord--last-time now))))

  (add-hook 'post-self-insert-hook #'my/multibyte-chord-detect))

;;; Common keybindings

(global-set-key (kbd "C-e") 'move-end-of-line)
(global-set-key (kbd "M-n") 'evil-forward-paragraph)
(global-set-key (kbd "M-p") 'evil-backward-paragraph)
(global-set-key (kbd "M-0") 'treemacs-select-window)
(global-set-key (kbd "M-<left>") 'subword-backward)
(global-set-key (kbd "M-<right>") 'subword-forward)

(global-set-key (kbd "C-/") 'comment-line)
(global-set-key (kbd "C-h") 'delete-backward-char)
(global-set-key (kbd "M-h") 'backward-kill-word)
(global-set-key (kbd "C-.") 'er/expand-region)
(global-set-key (kbd "C-o") 'crux-smart-open-line-above)
(global-set-key (kbd "C-m") 'crux-smart-open-line)
(global-set-key (kbd "C-<return>") 'electric-newline-and-maybe-indent)
(global-set-key (kbd "S-<down-mouse-1>") 'mouse-set-mark)
(global-set-key [remap dabbrev-expand] 'hippie-expand)

(add-hook 'doom-after-init-hook
          (lambda ()
            (global-set-key (kbd "C-z") 'undo)
            (global-set-key (kbd "C-S-z") 'undo-redo)))

(define-key isearch-mode-map (kbd "<up>") 'isearch-repeat-backward)
(define-key isearch-mode-map (kbd "<down>") 'isearch-repeat-forward)
(define-key minibuffer-local-isearch-map (kbd "<up>") 'isearch-reverse-exit-minibuffer)
(define-key minibuffer-local-isearch-map (kbd "<down>") 'isearch-forward-exit-minibuffer)

;;; Treemacs

(after! treemacs
  (dolist (fn '(treemacs-copy-absolute-path-at-point
                treemacs-copy-relative-path-at-point
                treemacs-copy-project-path-at-point))
    (advice-add fn :after
                (lambda (&rest _)
                  (when-let ((path (current-kill 0 t)))
                    (gui-set-selection 'CLIPBOARD path))))))

;;; Portable reading mode

;; Load the Doom-independent reading layer shared with the iOS profile.
(load! "platforms/ios/reader")

;;; EPUB reading

(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :init
  (when IS-WINDOWS
    ;; Emacs cannot spawn Scoop's shim here (it reports an exec format
    ;; error), so use the real Info-ZIP executable behind the shim.
    (setq nov-unzip-program
          (expand-file-name "scoop/apps/unzip/current/unzip.exe"
                            (getenv "USERPROFILE"))))
  :config
  (setq nov-text-width t
        nov-header-line-format nil)
  (add-hook 'nov-mode-hook #'visual-line-mode)

  (defun my/nov-tolerate-corrupt-fonts (orig-fn directory filename)
    "Allow EPUBs with corrupt embedded fonts to open when content extracted."
    ;; Windows process arguments and working directories can lose Cyrillic
    ;; characters.  Copy through Emacs' Unicode file API, then give unzip an
    ;; ASCII path inside nov's temporary extraction directory.
    (let* ((default-directory (file-name-as-directory directory))
           (local-filename (if IS-WINDOWS
                               (expand-file-name "source.epub" directory)
                             filename))
           (start (with-current-buffer (get-buffer-create "*nov unzip*")
                    (point-max-marker))))
      (when IS-WINDOWS
        (copy-file filename local-filename t))
      (unwind-protect
          (let ((status (funcall orig-fn directory local-filename)))
            (if (and (integerp status)
                     (> status 1)
                     (nov-epub-valid-p directory)
                     (get-buffer "*nov unzip*")
                     (with-current-buffer "*nov unzip*"
                       (save-excursion
                         (goto-char start)
                         (and (search-forward "invalid compressed data to inflate" nil t)
                              (search-backward "/Fonts/" start t)))))
                1
              status))
        (when (and IS-WINDOWS (file-exists-p local-filename))
          (delete-file local-filename)))))

  (advice-add 'nov-unzip-epub :around #'my/nov-tolerate-corrupt-fonts))

;;; Custom functions

(defun xah-select-line ()
  "Select current line. If region is active, extend selection downward by line.
If `visual-line-mode' is on, consider line as visual line."
  (interactive)
  (if (region-active-p)
      (if visual-line-mode
          (let ((xp1 (point)))
            (end-of-visual-line 1)
            (when (eq xp1 (point))
              (end-of-visual-line 2)))
        (progn
          (forward-line 1)
          (end-of-line)))
    (if visual-line-mode
        (progn
          (beginning-of-visual-line)
          (push-mark (point) t t)
          (end-of-visual-line))
      (push-mark (line-beginning-position) t t)
      (end-of-line))))

(defvar xah-brackets
  '("“”" "()" "[]" "{}" "<>" "＜＞" "（）" "［］" "｛｝" "⦅⦆" "〚〛"
    "⦃⦄" "‹›" "«»" "「」" "〈〉" "《》" "【】" "〔〕" "⦗⦘" "『』"
    "〖〗" "〘〙" "｢｣" "⟦⟧" "⟨⟩" "⟪⟫" "⟮⟯" "⟬⟭" "⌈⌉"
    "⌊⌋" "⦇⦈" "⦉⦊" "❛❜" "❝❞" "❨❩" "❪❫" "❴❵" "❬❭"
    "❮❯" "❰❱" "❲❳" "〈〉" "⦑⦒" "⧼⧽" "﹙﹚" "﹛﹜" "﹝﹞"
    "⁽⁾" "₍₎" "⦋⦌" "⦍⦎" "⦏⦐" "⁅⁆" "⸢⸣" "⸤⸥" "⟅⟆"
    "⦓⦔" "⦕⦖" "⸦⸧" "⸨⸩" "｟｠" "||")
  "Matching bracket pairs for `xah-select-text-in-quote'.")

(defun xah-select-text-in-quote ()
  "Select text between the nearest left and right delimiters."
  (interactive)
  (let ((xskipChars (concat "^\"`" (mapconcat #'identity xah-brackets ""))))
    (skip-chars-backward xskipChars)
    (push-mark (point) t t)
    (skip-chars-forward xskipChars)))

(defun xah-search-current-word ()
  "Call `isearch' on current word or selection."
  (interactive)
  (let (xbeg xend)
    (if (region-active-p)
        (setq xbeg (region-beginning)
              xend (region-end))
      (save-excursion
        (skip-chars-backward "-_A-Za-z0-9")
        (setq xbeg (point))
        (right-char)
        (skip-chars-forward "-_A-Za-z0-9")
        (setq xend (point))))
    (when (< xbeg (point))
      (goto-char xbeg))
    (isearch-mode t)
    (isearch-yank-string (buffer-substring-no-properties xbeg xend))))

(defun copy-relative-file-path-to-clipboard ()
  "Copy the current buffer's relative file path to the clipboard."
  (interactive)
  (if buffer-file-name
      (let ((file-path (substring (+default/yank-buffer-path (doom-project-root)) 13)))
        (with-temp-buffer
          (insert file-path)
          (clipboard-kill-ring-save (point-min) (point-max)))
        (message "Copied to clipboard: %s" file-path))
    (error "Buffer is not visiting a file")))

(defun copy-absolute-file-path-to-clipboard ()
  "Copy the current buffer's absolute file path to the clipboard."
  (interactive)
  (if buffer-file-name
      (let ((file-path (expand-file-name buffer-file-name)))
        (with-temp-buffer
          (insert file-path)
          (clipboard-kill-ring-save (point-min) (point-max)))
        (message "Copied to clipboard: %s" file-path))
    (error "Buffer is not visiting a file")))

;; `book-mode' is provided by platforms/ios/reader.el (loaded above), while
;; `ios/reading-mode' adds the read-only small-screen behavior used on iOS.

;;; File associations

(add-to-list 'auto-mode-alist '("\\.env\\(?:\\..*\\)?\\'" . dotenv-mode))

;;; Agent Shell

(require 'acp nil t)
(require 'agent-shell nil t)

;; Reopening a chat replays its whole conversation, not just its title.
(setq agent-shell-session-restore-verbosity 'full)

;; agent-shell pastes clipboard images by remapping `yank'; the platform paste
;; key runs `clipboard-yank', so remap that too.
(after! agent-shell
  (define-key agent-shell-mode-map [remap clipboard-yank] #'agent-shell-yank-dwim))
(after! agent-shell-viewport
  (define-key agent-shell-viewport-edit-mode-map [remap clipboard-yank] #'agent-shell-yank-dwim))

;;; Agent desk

;; One agent-shell copy per account, each with its own config dir.  Loaded on
;; first use (`M-x agent-desk'); registering adds the copies to agent-shell's
;; picker too.  Log an account in once with its CLI, e.g.
;; CLAUDE_CONFIG_DIR=~/.claude-2 claude, or CODEX_HOME=~/.codex-multi-2 codex login.
(use-package! agent-desk
  :commands (agent-desk agent-desk-new-chat agent-desk-toggle-sidebar
             agent-desk-toggle-details)
  :init
  (setq agent-desk-accounts
        '((:id claude-main :provider claude :label "Claude" :home "~/.claude")
          (:id claude-2 :provider claude :label "Claude·2" :home "~/.claude-2"
           :color "#e0a35a")
          (:id claude-gui2 :provider claude :label "Claude·G2" :home "~/.claude-gui-2"
           :color "#7aa2f7")
          (:id codex-main :provider codex :label "Codex" :home "~/.codex")
          (:id codex-2 :provider codex :label "Codex·2" :home "~/.codex-multi-2"
           :color "#9ece6a")))
  :config
  (agent-desk-register))

;;; Platform keybindings

(defvar my/platform-keybinding-format nil
  "Format string for platform keybindings, e.g. \"s-%s\" or \"C-c %s\".")

(defvar my/platform-extra-keybinding-keys nil
  "Platform-specific extra key strings as (ACTION . KEY) pairs.")

(defvar my/vterm-paste-source nil
  "Clipboard source for vterm paste. Either a shell command string or `gui-selection'.")

(defconst my/platform-keybinding-actions
  '(("x" . clipboard-kill-region)
    ("c" . clipboard-kill-ring-save)
    ("v" . clipboard-yank)
    ("j" . crux-top-join-line)
    ("k" . crux-kill-whole-line)
    ("w" . kill-current-buffer)
    ("t" . treemacs)
    ("q" . delete-window)
    ("D" . +default/search-project-for-symbol-at-point)
    ("r" . revert-buffer)
    ("R" . +vertico/search-symbol-at-point)
    ("y" . crux-duplicate-current-line-or-region)
    ("Y" . crux-duplicate-and-comment-current-line-or-region)
    ("1" . delete-other-windows)
    ("g" . magit-status)
    ("u" . +fold/toggle)
    ("]" . indent-rigidly-right-to-tab-stop)
    ("[" . indent-rigidly-left-to-tab-stop)
    ("l" . xah-select-line)
    ("i" . xah-select-text-in-quote)
    ("d" . xah-search-current-word))
  "Common platform keybinding actions keyed by platform-specific suffix.")

(defconst my/platform-extra-keybinding-actions
  '((new-buffer . +default/new-buffer)
    (previous-buffer . crux-switch-to-previous-buffer)
    (reload-buffer . revert-buffer))
  "Extra platform keybinding actions keyed by logical action name.")

(defun my/platform-keybinding (suffix)
  "Return the platform key string for SUFFIX."
  (format my/platform-keybinding-format suffix))

(defun my/vterm-paste-from-clipboard ()
  "Paste from the platform clipboard into vterm."
  (interactive)
  (vterm-send-string
   (or (pcase my/vterm-paste-source
         ('gui-selection (gui-get-selection 'CLIPBOARD 'STRING))
         ((pred stringp) (shell-command-to-string my/vterm-paste-source))
         (_ (user-error "No vterm paste source configured")))
       "")))

(defun my/apply-platform-keybindings ()
  "Install platform-specific keybindings from declarative platform config."
  (when my/platform-keybinding-format
    (dolist (binding my/platform-keybinding-actions)
      (global-set-key (kbd (my/platform-keybinding (car binding)))
                      (cdr binding))))
  (dolist (binding my/platform-extra-keybinding-keys)
    (when-let ((command (alist-get (car binding)
                                   my/platform-extra-keybinding-actions)))
      (global-set-key (kbd (cdr binding)) command)))
  (when (and my/platform-keybinding-format my/vterm-paste-source)
    (with-eval-after-load 'vterm
      (define-key vterm-mode-map
                  (kbd (my/platform-keybinding "v"))
                  #'my/vterm-paste-from-clipboard))))

(load! (format "platforms/keybindings-%s" my/platform))
(my/apply-platform-keybindings)

;;; Civet

(use-package! civet-mode
  :load-path "/Users/mac/projects/emacs/civet-mode"
  :mode "\\.civet\\'"
  :hook
  (civet-mode . (lambda ()
                  (setq-local treesit-font-lock-level 4)
                  (when (treesit-parser-list)
                    (treesit-font-lock-recompute-features)))))

;;; Sublime Text compatibility

(when (eq my/platform 'macos)
  (add-to-list 'load-path "/Users/mac/Documents/sublime.el")
  (when (require 'sublime nil t)
    (setq sublime-apply-font-size nil)
    (sublime-mode 1)))
