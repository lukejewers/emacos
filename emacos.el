;;; emacos.el --- Control macOS from Emacs -*- lexical-binding: t; -*-

;; Author: Luke Jewers
;; URL: https://github.com/lukejewers/emacos
;; Keywords: macOS emacs interface commands
;; Version 0.0.1

;;; License:

;; MIT License
;;
;; Copyright (c) 2026 Luke Jewers
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; emacos.el provides an interface for controlling macOS applications from Emacs.

;; Command                                     | Action
;; --------------------------------------------|------------------------------------------------
;; 'emacos-open-app'                           | Launch installed applications via `open -a'
;; 'emacos-close-app'                          | Quit running applications
;; 'emacos-open-file-in-firefox'               | Open selected file in firefox
;; 'emacos-open-file-in-chrome'                | Open selected file in chrome
;; 'emacos-reveal-file-at-point-in-finder'     | Open file at point in Finder
;; 'emacos-reveal-in-finder'                   | Open selected file in Finder with completion
;; 'emacos-open-trash'                         | Open Trash folder in Finder
;; 'emacos-empty-trash'                        | Permanently delete all items in Trash
;; 'emacos-get-file-path'                      | Copy absolute path of current file to kill ring
;; 'emacos-toggle-menu-bar'                    | Toggle visibility of the macOS menu bar
;; 'emacos-toggle-dock'                        | Toggle auto-hide behavior of the macOS dock
;; 'emacos-sleep-display'                      | Put display to sleep immediately

;;; Code:

(unless (eq system-type 'darwin)
  (display-warning 'emacos "The emacos package is designed exclusively for macOS." :warning))

;;;###autoload
(defgroup emacos nil
  "macOS interface commands."
  :group 'external)

;;;###autoload
(defcustom emacos-app-dirs
      '("/System/Applications" "/Applications" "~/Applications")
      "List of directories to search for .app bundles."
      :type '(repeat directory)
      :group 'emacos)

;;;###autoload
(defcustom emacos-screenshot-directory (expand-file-name "~/Screenshots")
  "Directory for saving screenshots."
  :group 'emacos)

;;;###autoload
(defun emacos-collect-apps ()
  "Return a list of all macOS applications in `emacos-app-dirs`."
  (let ((apps-acc nil))
    (dolist (dir emacos-app-dirs)
      (when (file-directory-p dir)
        (dolist (app-path (directory-files dir t "\\.app\\'"))
          (push (file-name-base app-path) apps-acc))))
    (when (file-directory-p "/System/Library/CoreServices/Finder.app")
      (push "Finder" apps-acc))
    (nreverse apps-acc)))

;;;###autoload
(defun emacos-collect-running-apps ()
  "Return a list of currently running, visible macOS applications."
  (let* ((cmd "osascript -e 'tell application \"System Events\" to get name of every process whose background only is false'")
         (raw  (shell-command-to-string cmd))
         (apps (split-string (string-trim raw) ",[ ]*")))
    (sort (delete-dups apps) #'string<)))

;;;###autoload
(defun emacos-open-app ()
  "Use `completing-read` to pick a macOS app and `open -a` it."
  (interactive)
  (let* ((apps (emacos-collect-apps))
         (choice (completing-read "macOS App: " (sort (delete-dups apps) #'string<) nil t)))
    (when choice
      (start-process
       (concat "open-" choice) nil
       "open" "-a" choice)
      (message "Opening %s" choice))))

;;;###autoload
(defun emacos-close-app ()
  "Use `completing-read` to pick a running macOS app and tell it to quit."
  (interactive)
  (let* ((running-apps (emacos-collect-running-apps)))
    (if (null running-apps)
        (user-error "No running applications found")
      (let ((choice (completing-read "Quit macOS App: " running-apps nil t)))
        (unless (member choice running-apps)
          (user-error "Application '%s' is not currently running" choice))
        (start-process
         (concat "quit-" choice) nil
         "osascript" "-e" (format "tell application \"%s\" to quit" choice))
        (message "Told %s to quit" choice)))))

;;;###autoload
(defun emacos-open-file-in-firefox ()
  "Open the current buffer's file in the macOS Firefox application."
  (interactive)
  (let ((file-to-open (buffer-file-name)))
    (unless file-to-open
      (user-error "Current buffer is not visiting a file"))
    (unless (file-exists-p file-to-open)
      (user-error "File does not exist: %s" file-to-open))
    (start-process
     "open-in-firefox" nil
     "open" "-a" "Firefox" file-to-open)
    (message "Opening %s in Firefox..." (file-name-nondirectory file-to-open))))

;;;###autoload
(defun emacos-open-file-in-chrome ()
  "Open the current buffer's file in the macOS Google Chrome application."
  (interactive)
  (let ((file-to-open (buffer-file-name)))
    (unless file-to-open
      (user-error "Current buffer is not visiting a file"))
    (unless (file-exists-p file-to-open)
      (user-error "File does not exist: %s" file-to-open))
    (start-process
     "open-in-chrome" nil
     "open" "-a" "Google Chrome" file-to-open)
    (message "Opening %s in Google Chrome..." (file-name-nondirectory file-to-open))))

;;;###autoload
(defun emacos-open-trash ()
  "Open the macOS Trash folder in Finder."
  (interactive)
  (condition-case err
      (progn
        (start-process "open-trash" nil "open" (expand-file-name "~/.Trash"))
        (message "Trash opened successfully"))
    (error
     (message "Error opening Trash: %s" (error-message-string err)))))

;;;###autoload
(defun emacos-empty-trash ()
  "Empty the macOS trash. Shows a success message or error if emptying fails."
  (interactive)
  (when (y-or-n-p "Permanently delete all items in the trash? ")
    (condition-case err
        (let ((script "tell application \"Finder\" to empty trash"))
          (start-process "empty-trash" nil "osascript" "-e" script)
          (message "Trash emptied successfully"))
      (error
       (message "Error emptying trash: %s" (error-message-string err))))))

;;;###autoload
(defun emacos-reveal-in-finder (file)
  "Reveal FILE in Finder with completion."
  (interactive (list (read-file-name "Reveal file: ")))
  (start-process "reveal-file" nil "open" "-R" file))

;;;###autoload
(defun emacos-reveal-file-at-point-in-finder ()
  "Reveal current file/directory at point in macOS Finder.
When called from a file buffer, reveals the current file.
When called from a dired buffer, reveals the file/directory at point.
If not on a file/directory in dired, reveals the current directory."
  (interactive)
  (let (filename)
    (cond
     ((derived-mode-p 'dired-mode)
      (setq filename (or (dired-get-filename nil t) (dired-current-directory))))
     ((buffer-file-name)
      (setq filename (buffer-file-name)))
     (t (user-error "Not in a file or dired buffer")))

    (unless (file-exists-p filename)
      (user-error "File does not exist: %s" filename))

    (start-process "reveal-in-finder" nil "open" "-R" filename)
    (message "Revealing %s in Finder" (file-name-nondirectory filename))))

;;;###autoload
(defun emacos-get-file-path ()
  "Copy absolute path of current file to kill ring."
  (interactive)
  (let ((path (or (buffer-file-name) default-directory)))
    (kill-new path)
    (message "Copied: %s" path)))

;;;###autoload
(defun emacos-toggle-menu-bar ()
  "Toggle visibility of the macOS menu bar."
  (interactive)
  (let* ((script "tell application \"System Events\"
                    tell dock preferences
                        set autohide menu bar to not autohide menu bar
                    end tell
                  end tell")
         (result (shell-command-to-string (concat "osascript -e " (shell-quote-argument script)))))
    (message "Toggled menu bar visibility")))

;;;###autoload
(defun emacos-toggle-dock ()
  "Toggle auto-hide behavior of the macOS dock."
  (interactive)
  (let* ((script "tell application \"System Events\"
                    tell dock preferences
                        set autohide to not autohide
                    end tell
                  end tell")
         (result (shell-command-to-string (concat "osascript -e " (shell-quote-argument script)))))
    (message "Toggled dock auto-hide behavior")))

;;;###autoload
(defun emacos-sleep-display ()
  "Put display to sleep immediately."
  (interactive)
  (start-process "sleep-display" nil "pmset" "displaysleepnow"))

(provide 'emacos)

;;; emacos.el ends here
