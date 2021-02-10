;;; sniem-object-catch.el --- Simple united editing method -*- lexical-binding: t -*-

;; Author: SpringHan
;; Maintainer: SpringHan
;; Version: 1.0
;; Package-Requires: ((emacs) (s "20180406.808") (dash "20200524.1947"))
;; Homepage: https://github.com/SpringHan/sniem.git
;; Keywords: Editing Method


;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.


;;; Commentary:

;; Simple united editing method

;;; Code:

(defgroup sniem-object-catch nil
  "The group of `sniem-object-catch'."
  :group 'sniem)

(defcustom sniem-object-catch-global-symbol-alist
  '(("\"" . "\"")
    ("'" . "'")
    ("[" . "]")
    ("<" . ">")
    ("(" . ")")
    ("{" . "}"))
  "The global symbol alist."
  :group 'sniem-object-catch)

(defcustom sniem-object-catch-last-points nil
  "The last point cons."
  :type 'cons
  :group 'sniem-object-catch)

(defcustom sniem-object-catch-action nil
  "The action info for the last catch."
  :type 'cons
  :group 'sniem-object-catch)

(defcustom sniem-object-catch-forward-p nil
  "The direction for catch."
  :type 'symbol
  :group 'sniem-object-catch)

(defcustom sniem-object-catch-prefix-string-p nil
  "If the prefix is string."
  :type 'boolean
  :group 'sniem-object-catch)

(defvar global-sniem-object-catch-status nil
  "The status for `global-sniem-object-catch-mode'")

(sniem-define-motion sniem-object-catch (&optional char parent)
  "Catch region."
  (interactive)
  (let ((point (point)))
    (while (not (eq 'no (ignore-errors (sniem-object-catch--get char parent))))
      (if (bobp)
          (progn
            (goto-char point)
            (keyboard-quit))
        (backward-char)))
    (when sniem-object-catch-prefix-string-p
      (setq-local sniem-object-catch-prefix-string-p nil))))

(defun sniem-object-catch--get (char parent)
  "Get the object."
  (let ((move (if sniem-object-catch-forward-p
                  'forward-char
                'backward-char))
        prefix-point second-char second-point tmp go-on)
    (save-mark-and-excursion
      (when (region-active-p)
        (funcall move))
      ;; Get the `prefix-point'
      (if char
          (setq prefix-point
                (catch 'point-stop
                  (while t
                    (if (string=
                         char
                         (setq tmp
                               (buffer-substring-no-properties (point) (1+ (point)))))
                        (throw 'point-stop (point))
                      (if (or (bobp) (eobp))
                          (throw 'point-stop nil)
                        (funcall move))))))
        (setq prefix-point
              (catch 'point-stop
                (while t
                  (if (sniem-object-catch--get-second-char
                       (setq tmp (buffer-substring-no-properties (point) (1+ (point)))))
                      (progn
                        (setq char tmp)
                        (throw 'point-stop (point)))
                    (if (or (bobp) (eobp))
                        (throw 'point-stop nil)
                      (funcall move)))))))

      (when (and (string= char "'") (sniem-object-catch-lisp-mode-p))
        (setq go-on t))
      (when (nth 3 (syntax-ppss prefix-point))
        (setq-local sniem-object-catch-prefix-string-p t))
      (if (not char)
          (message "[Sniem-Object-Catch]: Can not find a symbol in alist.")
        (setq second-char (sniem-object-catch--get-second-char char)
              second-point (if (string= char second-char)
                               (sniem-object-catch-format-point2 char prefix-point)
                             (sniem-object-catch-format-point char second-char)))
        (when (consp second-point)
          (setq prefix-point (car second-point)
                second-point (cdr second-point)))
        (if (and parent sniem-object-catch-last-points
                 (> (cdr sniem-object-catch-last-points) second-point))
            (setq go-on t)
          (setq-local sniem-object-catch-last-points (cons prefix-point second-point)))))
    (goto-char prefix-point)
    (push-mark second-point t t)
    (setq-local sniem-object-catch-action `(,char . ,parent))
    (unless go-on
      (setq go-on 'no))
    go-on))

(defun sniem-object-catch-by-char (char)
  "Catch region by CHAR."
  (interactive (list (char-to-string (read-char))))
  (if (sniem-object-catch--get-second-char char)
      (sniem-object-catch char)
    (message "[Sniem-Object-Catch]: %s is not defined in the symbol alist." char)))

(defun sniem-object-catch-round ()
  "Catch region by `('."
  (interactive)
  (sniem-object-catch-by-char "("))

(defun sniem-object-catch-square ()
  "Catch region by `['."
  (interactive)
  (sniem-object-catch-by-char "["))

(defun sniem-object-catch-curly ()
  "Catch region by `{'."
  (interactive)
  (sniem-object-catch-by-char "{"))

(defun sniem-object-catch-parent ()
  "Catch region for its parent."
  (interactive)
  (sniem-object-catch nil t))

(defun sniem-object-catch-parent-by-char (char)
  "Catch region for its parent by CHAR."
  (interactive (list (char-to-string (read-char))))
  (if (sniem-object-catch--get-second-char char)
      (sniem-object-catch char t)
    (message "[Sniem-Object-Catch]: %s is not defined in the symbol alist.")))

(defun sniem-object-catch-repeat ()
  "Repeat the last catch."
  (interactive)
  (when sniem-object-catch-action
    (sniem-object-catch (car sniem-object-catch-action) (cdr sniem-object-catch-action))))

(defun sniem-object-catch-direction-reverse (&optional forward)
  "Reverse the catch direction."
  (interactive)
  (setq-local sniem-object-catch-forward-p
              (if (or forward (null sniem-object-catch-forward-p))
                  t
                nil))
  (message "[Sniem]: The object-catch-direction now is %s."
           (if sniem-object-catch-forward-p
               "forward"
             "backward")))

(defun sniem-object-catch-format-point (prefix second-char)
  "Format point with the PREFIX."
  (let ((times 1)
        tmp)
    (forward-char)
    (while (/= times 0)
      (setq tmp (buffer-substring-no-properties (point) (1+ (point))))
      (cond ((and (string= tmp prefix) (not (string= prefix second-char))
                  (not (nth 3 (syntax-ppss)))
                  (not (sniem-object-catch-backslash-p)))
             (setq times (1+ times)))
            ((and (string= tmp second-char) (> times 0)
                  (not (sniem-object-catch-backslash-p))
                  (eq sniem-object-catch-prefix-string-p (nth 3 (syntax-ppss))))
             (setq times (1- times)))
            ((and (string= tmp second-char) (= times -1))
             (setq times 0)))
      (forward-char))
    (point)))

(defun sniem-object-catch-format-point2 (pair prefix-point)
  "Format point for the pair with same char."
  (let ((region-forward-p (when (and (region-active-p) sniem-object-catch-forward-p)
                            (prog1 (cons (region-beginning) (region-end))
                              (deactivate-mark))))
        prefix-face second-point)
    (save-mark-and-excursion
      (goto-char prefix-point)
      (setq prefix-face (face-at-point))
      (cond ((progn
               (backward-char)
               (eq (face-at-point) prefix-face))
             (setq second-point (sniem-object-catch-format-point1 pair prefix-point)
                   prefix-point (sniem-object-catch-format-point1 pair prefix-point t t)))
             
            ((progn
               (forward-char 2)
               (or (eq (face-at-point) prefix-face)
                   (eq (face-at-point) 'show-paren-match))) ;NOTE: This expression in here maybe have bug.
             (setq prefix-point (sniem-object-catch-format-point1 pair prefix-point nil t)
                   second-point (sniem-object-catch-format-point1 pair (point) t))))
      (when region-forward-p
        (goto-char (car region-forward-p))
        (push-mark (cdr region-forward-p)))
      (cons prefix-point (1+ second-point)))))

(defun sniem-object-catch-format-point1 (pair point &optional search prefix)
  "Format the point for char."
  (save-mark-and-excursion
    (goto-char point)
    (let ((search-command (if prefix
                              'search-backward
                            'search-forward)))
      (when search
        (setq point (progn
                      (funcall search-command pair)
                      (unless prefix (backward-char))
                      (point))))
      (when (prog2 (backward-char) (= (following-char) 92)
              (forward-char))
        (setq point (progn
                      (forward-char)
                      (point)))
        (while (prog3
                 (setq point (funcall search-command pair))
                 (backward-char)
                 (= (following-char) 92)
                 (forward-char)))))
    point))

(defun sniem-object-catch--get-second-char (prefix)
  "Get the second char by the PREFIX."
  (catch 'second-char
    (dolist (char-cons sniem-object-catch-global-symbol-alist)
      (when (string= prefix (car char-cons))
        (throw 'second-char (cdr-safe char-cons))))))

(defun sniem-object-catch--symbol-exists-p (symbol)
  "Check if the SYMBOL is exists."
  (catch 'exists
    (let ((index 0))
      (dolist (symbol-cons sniem-object-catch-global-symbol-alist)
        (when (string= symbol (car symbol-cons))
          (throw 'exists index))
        (setq index (1+ index))))))

(defun sniem-object-catch-lisp-mode-p ()
  "Check if the current major mode belongs to lisp mode."
  (string-match-p "\\(?:.*\\)lisp\\(?:.*\\)" (symbol-name major-mode)))

(defmacro prog3 (form1 form2 form3 &rest body)
  "Eval FORM1, FORM2, FORM3 and body, return the FORM3."
  (declare (indent 0) (debug t))
  `(progn ,form1 ,form2 (prog1 ,form3 ,@body)))

(defun sniem-object-catch-backslash-p ()
  "Check if the char before current point is \\."
  (= 92 (char-before)))

(defmacro sniem-object-catch-mode-defalist (mode-name &rest alist)
  "Define alist for major mode."
  (declare (indent 1))
  `(let ((sym-alist sniem-object-catch-global-symbol-alist)
         tmp)
     (dolist (list ',alist)
       (if (setq tmp (sniem-object-catch--symbol-exists-p (car list)))
           (setf (cdr (nth tmp sym-alist)) (cdr list))
         (add-to-list 'sym-alist list)))
     (add-hook (intern (concat (symbol-name ',mode-name) "-hook"))
               `(lambda () (setq-local sniem-object-catch-global-symbol-alist
                                       ',sym-alist)))))

(add-hook 'deactivate-mark-hook #'(lambda ()
                                    (when sniem-object-catch-last-points
                                      (setq-local sniem-object-catch-last-points nil))))

(sniem-normal-set-key
 "(" 'sniem-object-catch-round
 "[" 'sniem-object-catch-square
 "{" 'sniem-object-catch-curly
 "<C-M-return>" 'sniem-object-catch-parent-by-char)

(provide 'sniem-object-catch)

;;; sniem-object-catch.el ends here
