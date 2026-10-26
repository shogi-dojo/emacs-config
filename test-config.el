;;; test-config.el --- ERT tests for the unified Doom config -*- lexical-binding: t; -*-
;;
;; Run with:
;;   emacs --batch -l ert -l test-config.el -f ert-run-tests-batch-and-exit

;;; Platform detection

(ert-deftest test-platform-detection-darwin ()
  "On darwin, my/platform should be macos."
  (let ((system-type 'darwin))
    (should (eq (cond
                 ((eq system-type 'darwin) 'macos)
                 ((and (eq system-type 'gnu/linux)
                       (or (getenv "TERMUX_VERSION")
                           (file-directory-p "/data/data/com.termux")))
                  'android)
                 ((eq system-type 'gnu/linux) 'linux)
                 (t 'linux))
                'macos))))

(ert-deftest test-platform-detection-linux ()
  "On gnu/linux without Termux markers, my/platform should be linux."
  (let ((system-type 'gnu/linux))
    (cl-letf (((symbol-function 'getenv) (lambda (var) (when (string= var "TERMUX_VERSION") nil)))
             ((symbol-function 'file-directory-p) (lambda (_) nil)))
      (should (eq (cond
                   ((eq system-type 'darwin) 'macos)
                   ((and (eq system-type 'gnu/linux)
                         (or (getenv "TERMUX_VERSION")
                             (file-directory-p "/data/data/com.termux")))
                    'android)
                   ((eq system-type 'gnu/linux) 'linux)
                   (t 'linux))
                  'linux)))))

(ert-deftest test-platform-detection-windows ()
  "On windows-nt, my/platform should be windows."
  (let ((system-type 'windows-nt))
    (should (eq (cond
                 ((eq system-type 'darwin) 'macos)
                 ((eq system-type 'android) 'android)
                 ((and (eq system-type 'gnu/linux)
                       (or (getenv "TERMUX_VERSION")
                           (file-directory-p "/data/data/com.termux")))
                  'android)
                 ((eq system-type 'gnu/linux) 'linux)
                 ((eq system-type 'windows-nt) 'windows)
                 (t 'linux))
                'windows))))

(ert-deftest test-platform-detection-android-env ()
  "On gnu/linux with TERMUX_VERSION env var, my/platform should be android."
  (let ((system-type 'gnu/linux))
    (cl-letf (((symbol-function 'getenv)
               (lambda (var) (when (string= var "TERMUX_VERSION") "0.118.0")))
             ((symbol-function 'file-directory-p) (lambda (_) nil)))
      (should (eq (cond
                   ((eq system-type 'darwin) 'macos)
                   ((and (eq system-type 'gnu/linux)
                         (or (getenv "TERMUX_VERSION")
                             (file-directory-p "/data/data/com.termux")))
                    'android)
                   ((eq system-type 'gnu/linux) 'linux)
                   (t 'linux))
                  'android)))))

(ert-deftest test-platform-detection-android-dir ()
  "On gnu/linux with Termux directory, my/platform should be android."
  (let ((system-type 'gnu/linux))
    (cl-letf (((symbol-function 'getenv) (lambda (_) nil))
             ((symbol-function 'file-directory-p)
              (lambda (dir) (string= dir "/data/data/com.termux"))))
      (should (eq (cond
                   ((eq system-type 'darwin) 'macos)
                   ((and (eq system-type 'gnu/linux)
                         (or (getenv "TERMUX_VERSION")
                             (file-directory-p "/data/data/com.termux")))
                    'android)
                   ((eq system-type 'gnu/linux) 'linux)
                   (t 'linux))
                  'android)))))

(ert-deftest test-platform-detection-unknown-falls-to-linux ()
  "Unknown system-type should fall back to linux."
  (let ((system-type 'windows-nt))
    (should (eq (cond
                 ((eq system-type 'darwin) 'macos)
                 ((and (eq system-type 'gnu/linux)
                       (or (getenv "TERMUX_VERSION")
                           (file-directory-p "/data/data/com.termux")))
                  'android)
                 ((eq system-type 'gnu/linux) 'linux)
                 (t 'linux))
                'linux))))

;;; Keybinding format

(ert-deftest test-keybinding-format-macos ()
  "macOS keybinding format produces s- prefixed keys."
  (let ((my/platform-keybinding-format "s-%s"))
    (should (string= (format my/platform-keybinding-format "c") "s-c"))
    (should (string= (format my/platform-keybinding-format "D") "s-D"))
    (should (string= (format my/platform-keybinding-format "]") "s-]"))))

(ert-deftest test-keybinding-format-linux ()
  "Linux keybinding format produces C-c prefixed keys."
  (let ((my/platform-keybinding-format "C-c %s"))
    (should (string= (format my/platform-keybinding-format "c") "C-c c"))
    (should (string= (format my/platform-keybinding-format "D") "C-c D"))))

(ert-deftest test-keybinding-format-windows ()
  "Windows reuses the Linux C-c keybinding format."
  (let ((my/platform-keybinding-format "C-c %s"))
    (should (string= (format my/platform-keybinding-format "c") "C-c c"))
    (should (string= (format my/platform-keybinding-format "D") "C-c D"))))

(ert-deftest test-keybinding-format-android ()
  "Android keybinding format produces A- prefixed keys."
  (let ((my/platform-keybinding-format "A-%s"))
    (should (string= (format my/platform-keybinding-format "c") "A-c"))
    (should (string= (format my/platform-keybinding-format "v") "A-v"))))

;;; Keybinding actions

(ert-deftest test-keybinding-actions-complete ()
  "All expected keybinding suffixes should be present."
  (let ((my/platform-keybinding-actions
         '(("x" . clipboard-kill-region)
           ("c" . clipboard-kill-ring-save)
           ("v" . clipboard-yank)
           ("j" . crux-top-join-line)
           ("k" . crux-kill-whole-line)
           ("w" . kill-current-buffer)
           ("t" . treemacs)
           ("q" . delete-window)
           ("D" . +default/search-project-for-symbol-at-point)
           ("r" . +vertico/search-symbol-at-point)
           ("y" . crux-duplicate-current-line-or-region)
           ("Y" . crux-duplicate-and-comment-current-line-or-region)
           ("1" . delete-other-windows)
           ("g" . magit-status)
           ("u" . +fold/toggle)
           ("]" . indent-rigidly-right-to-tab-stop)
           ("[" . indent-rigidly-left-to-tab-stop)
           ("l" . xah-select-line)
           ("i" . xah-select-text-in-quote)
           ("d" . xah-search-current-word))))
    (should (= (length my/platform-keybinding-actions) 20))
    (should (assoc "x" my/platform-keybinding-actions))
    (should (assoc "v" my/platform-keybinding-actions))
    (should (eq (cdr (assoc "g" my/platform-keybinding-actions)) 'magit-status))))

;;; Extra keybinding actions

(ert-deftest test-extra-keybinding-actions ()
  "Extra keybinding action symbols should map to functions."
  (let ((my/platform-extra-keybinding-actions
         '((new-buffer . +default/new-buffer)
           (previous-buffer . crux-switch-to-previous-buffer)
           (reload-buffer . revert-buffer))))
    (should (eq (alist-get 'new-buffer my/platform-extra-keybinding-actions)
                '+default/new-buffer))
    (should (eq (alist-get 'reload-buffer my/platform-extra-keybinding-actions)
                'revert-buffer))))

;;; Platform file existence

(ert-deftest test-platform-files-exist ()
  "All platform files should exist in the platforms/ directory."
  (let ((dir (file-name-directory (or load-file-name
                                      buffer-file-name
                                      default-directory))))
    (dolist (file '("platforms/macos.el"
                    "platforms/linux.el"
                    "platforms/windows.el"
                    "platforms/android.el"
                    "platforms/keybindings-macos.el"
                    "platforms/keybindings-linux.el"
                    "platforms/keybindings-windows.el"
                    "platforms/keybindings-android.el"))
      (should (file-exists-p (expand-file-name file dir))))))

;;; Smoke test: config.el parses without errors

(ert-deftest test-config-parses ()
  "config.el should be valid elisp that can be read without errors."
  (let* ((dir (file-name-directory (or load-file-name
                                       buffer-file-name
                                       default-directory)))
         (config-file (expand-file-name "config.el" dir)))
    (with-temp-buffer
      (insert-file-contents config-file)
      (condition-case err
          (while (not (eobp))
            (read (current-buffer)))
        (end-of-file nil)  ; expected — means we read all forms
        (error (ert-fail (format "Parse error in config.el: %s" err)))))))

(ert-deftest test-init-parses ()
  "init.el should be valid elisp that can be read without errors."
  (let* ((dir (file-name-directory (or load-file-name
                                       buffer-file-name
                                       default-directory)))
         (init-file (expand-file-name "init.el" dir)))
    (with-temp-buffer
      (insert-file-contents init-file)
      (condition-case err
          (while (not (eobp))
            (read (current-buffer)))
        (end-of-file nil)
        (error (ert-fail (format "Parse error in init.el: %s" err)))))))

(ert-deftest test-packages-parses ()
  "packages.el should be valid elisp that can be read without errors."
  (let* ((dir (file-name-directory (or load-file-name
                                       buffer-file-name
                                       default-directory)))
         (pkg-file (expand-file-name "packages.el" dir)))
    (with-temp-buffer
      (insert-file-contents pkg-file)
      (condition-case err
          (while (not (eobp))
            (read (current-buffer)))
        (end-of-file nil)
        (error (ert-fail (format "Parse error in packages.el: %s" err)))))))

(ert-deftest test-agent-desk-is-a-local-package ()
  "agent-desk should be declared from its local checkout, not a remote."
  (let* ((dir (file-name-directory (or load-file-name
                                       buffer-file-name
                                       default-directory)))
         (forms (with-temp-buffer
                  (insert-file-contents (expand-file-name "packages.el" dir))
                  (let (forms)
                    (condition-case nil
                        (while t (push (read (current-buffer)) forms))
                      (end-of-file nil))
                    forms)))
         (decl (seq-find (lambda (form)
                           (equal (seq-take form 2) '(package! agent-desk)))
                         forms))
         (recipe (plist-get (cddr decl) :recipe)))
    (should decl)
    (should (equal (plist-get recipe :local-repo) "~/projects/emacs/agent-desk"))
    (should-not (plist-get recipe :host))))

(ert-deftest test-all-platform-files-parse ()
  "All platform .el files should be valid elisp."
  (let ((dir (file-name-directory (or load-file-name
                                      buffer-file-name
                                      default-directory))))
    (dolist (file '("platforms/macos.el"
                    "platforms/linux.el"
                    "platforms/windows.el"
                    "platforms/android.el"
                    "platforms/keybindings-macos.el"
                    "platforms/keybindings-linux.el"
                    "platforms/keybindings-windows.el"
                    "platforms/keybindings-android.el"))
      (with-temp-buffer
        (insert-file-contents (expand-file-name file dir))
        (condition-case err
            (while (not (eobp))
              (read (current-buffer)))
          (end-of-file nil)
          (error (ert-fail (format "Parse error in %s: %s" file err))))))))

;;; No duplicates across platform files

(ert-deftest test-no-duplicate-setq-across-platforms ()
  "Variables set in common config should not be redundantly set in platform files."
  (let* ((dir (file-name-directory (or load-file-name
                                       buffer-file-name
                                       default-directory)))
         (common-vars '())
         (platform-files '("platforms/macos.el"
                           "platforms/linux.el"
                           "platforms/windows.el"
                           "platforms/android.el")))
    ;; Collect variable names from setq forms in config.el
    (with-temp-buffer
      (insert-file-contents (expand-file-name "config.el" dir))
      (goto-char (point-min))
      (while (re-search-forward "(setq \\([a-z][a-z/-]*\\)" nil t)
        (push (match-string 1) common-vars)))
    ;; Check platform files don't re-set scroll-margin, jit-lock-defer-time, etc.
    (dolist (pfile platform-files)
      (with-temp-buffer
        (insert-file-contents (expand-file-name pfile dir))
        (goto-char (point-min))
        (while (re-search-forward "\\bscroll-margin\\b" nil t)
          (ert-fail (format "%s sets scroll-margin (should be in common config)" pfile)))
        (goto-char (point-min))
        (while (re-search-forward "\\bvterm-max-scrollback\\b" nil t)
          (ert-fail (format "%s sets vterm-max-scrollback (should be in common config)" pfile)))
        (goto-char (point-min))
        (while (re-search-forward "\\bjit-lock-defer-time\\b" nil t)
          (ert-fail (format "%s sets jit-lock-defer-time (should be in common config)" pfile)))))))

(provide 'test-config)
;;; test-config.el ends here
