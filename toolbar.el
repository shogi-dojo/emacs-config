;;; toolbar.el -*- lexical-binding: t; -*-

;; Flat, monochrome Lucide icons (ISC, bundled in icons/toolbar/) in place of
;; the default tool bar's raster images.  The actions and their :enable
;; conditions stay as Emacs defines them; only each item's :image changes.
;; Icons are tinted from the theme, so they're rebuilt on every theme load.

(defvar my/toolbar-icon-dir (expand-file-name "icons/toolbar/" doom-user-dir)
  "Directory holding the tool bar's SVG icons.")

(defvar my/toolbar-icons
  '((new-file        . "file-plus")
    (open-file       . "folder-open")
    (open-directory  . "folder-tree")
    (kill-buffer     . "x")
    (save-buffer     . "save")
    (undo            . "undo-2")
    (cut             . "scissors")
    (copy            . "copy")
    (paste           . "clipboard-paste")
    (isearch-forward . "search"))
  "Tool bar keys and the icon file (without .svg) each one shows.")

(defvar my/toolbar-icon-size 20
  "Logical pixel size of a tool bar icon.")

(defun my/toolbar--image (name color)
  "Return icon NAME as an SVG image whose strokes are drawn in COLOR."
  (let ((svg (with-temp-buffer
               (insert-file-contents (expand-file-name (concat name ".svg")
                                                       my/toolbar-icon-dir))
               (buffer-string))))
    (create-image (string-replace "currentColor" color svg) 'svg t
                  :width my/toolbar-icon-size :height my/toolbar-icon-size)))

(defun my/toolbar-apply-icons ()
  "Swap the default tool bar's images for themed SVG icons."
  (when (image-type-available-p 'svg)
    (let ((color (or (and (fboundp 'doom-color) (doom-color 'base7)) "gray70"))
          (map (default-value 'tool-bar-map)))
      (pcase-dolist (`(,key . ,name) my/toolbar-icons)
        (when-let* ((item (assq key map))
                    ((eq (car-safe (cdr item)) 'menu-item)))
          (plist-put (nthcdr 4 item) :image (my/toolbar--image name color))))
      ;; tool-bar.el caches each map's evaluated keymap, images included.
      (clrhash tool-bar-keymap-cache)
      (force-mode-line-update t))))

(my/toolbar-apply-icons)
(add-hook 'doom-load-theme-hook #'my/toolbar-apply-icons)
