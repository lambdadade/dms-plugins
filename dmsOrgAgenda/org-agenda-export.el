;;; org-agenda-export.el --- Export org-agenda items as JSON -*- lexical-binding: t; -*-
;;
;; Usage:
;;   emacs --batch -l ~/.emacs.d/init.el -l org-agenda-export.el \
;;     --eval '(org-agenda-export-json 3 14 "~/org")'
;;
;; Output: JSON array on stdout, errors on stderr

(require 'org)
(require 'json)

(defun org-agenda-export--format-date (time)
  "Format TIME as YYYY-MM-DD string."
  (format-time-string "%Y-%m-%d" time))

(defun org-agenda-export--format-time (time)
  "Format TIME as HH:MM string."
  (format-time-string "%H:%M" time))

(defun org-agenda-export--has-time-p (timestamp-str)
  "Return non-nil if TIMESTAMP-STR contains a time component."
  (and timestamp-str
       (string-match-p "[0-9]\\{1,2\\}:[0-9]\\{2\\}" timestamp-str)))

(defun org-agenda-export--parse-ts (timestamp-str)
  "Parse org TIMESTAMP-STR and return time value, or nil."
  (when (and timestamp-str (not (string-empty-p timestamp-str)))
    (condition-case nil
        (let ((parsed (org-parse-time-string timestamp-str)))
          (encode-time parsed))
      (error nil))))

(defun org-agenda-export--body-timestamps ()
  "Return list of active timestamp strings found in the current entry body.
Skips planning lines, property drawers, and CLOCK lines."
  (let* ((end (save-excursion (org-end-of-subtree t t)))
         (beg (save-excursion
                (org-back-to-heading t)
                (forward-line 1)
                (when (looking-at org-planning-line-re)
                  (forward-line 1))
                (when (looking-at org-property-drawer-re)
                  (goto-char (match-end 0))
                  (forward-line 1))
                (point)))
         (timestamps nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward org-ts-regexp end t)
        (unless (save-excursion
                  (beginning-of-line)
                  (looking-at ".*CLOCK:"))
          (push (match-string 0) timestamps))))
    (nreverse timestamps)))

(defun org-agenda-export--make-item (heading date time-str category
                                     priority-char todo-state tags-list
                                     type file today)
  "Build an alist for one agenda item."
  `((title . ,heading)
    (date . ,date)
    (time . ,time-str)
    (endTime . "")
    (category . ,category)
    (priority . ,(or priority-char ""))
    (todoState . ,(or todo-state ""))
    (tags . ,(vconcat tags-list))
    (type . ,type)
    (file . ,file)
    (isOverdue . ,(if (and (not (member todo-state
                                        (or org-done-keywords '("DONE"))))
                           (string< date today))
                      t json-false))
    (isToday . ,(if (string= date today) t json-false))))

(defun org-agenda-export--process-timestamp (ts-str heading category
                                             priority-char todo-state
                                             tags-list type file
                                             start-day end-day today)
  "Process a single timestamp TS-STR and return item alist or nil."
  (let* ((ts-time (org-agenda-export--parse-ts ts-str))
         (ts-date (when ts-time
                    (org-agenda-export--format-date ts-time)))
         (has-time (org-agenda-export--has-time-p ts-str)))
    (when (and ts-date
               (not (string< ts-date start-day))
               (not (string> ts-date end-day)))
      (org-agenda-export--make-item
       heading ts-date
       (if has-time (org-agenda-export--format-time ts-time) "")
       category priority-char todo-state tags-list type file today))))

(defun org-agenda-export-json (days-back days-forward &optional org-dir)
  "Export org-agenda entries as JSON array to stdout.
DAYS-BACK: how many days in the past to include.
DAYS-FORWARD: how many days in the future to include.
ORG-DIR: optional org-directory override (expands ~ automatically)."
  (condition-case err
      (let* ((org-dir-expanded (when org-dir
                                 (expand-file-name org-dir)))
             (files (cond
                     ((and org-dir-expanded (file-directory-p org-dir-expanded))
                      (directory-files-recursively org-dir-expanded "\\.org$"))
                     ((bound-and-true-p org-agenda-files)
                      (org-agenda-files t))
                     ((and (bound-and-true-p org-directory)
                           (file-directory-p org-directory))
                      (directory-files-recursively org-directory "\\.org$"))
                     (t '())))
             (now (current-time))
             (start-time (time-subtract now (days-to-time days-back)))
             (end-time (time-add now (days-to-time days-forward)))
             (start-day (org-agenda-export--format-date start-time))
             (end-day (org-agenda-export--format-date end-time))
             (today (org-agenda-export--format-date now))
             (results '()))

        ;; Process each org file
        (dolist (file files)
          (when (and (file-exists-p file) (file-readable-p file))
            (condition-case file-err
                (with-temp-buffer
                  (insert-file-contents file)
                  (org-mode)
                  (org-map-entries
                   (lambda ()
                     (let* ((heading (org-get-heading t t t t))
                            (tags-list (org-get-tags))
                            (priority-char (org-entry-get nil "PRIORITY"))
                            (todo-state (org-get-todo-state))
                            (category (or (org-get-category) ""))
                            (scheduled-str (org-entry-get nil "SCHEDULED"))
                            (deadline-str (org-entry-get nil "DEADLINE"))
                            (timestamp-str (org-entry-get nil "TIMESTAMP"))
                            (closed-str (org-entry-get nil "CLOSED"))
                            (item nil))

                       ;; Skip DONE items with CLOSED timestamp
                       (unless (and todo-state
                                    (member todo-state (or org-done-keywords '("DONE")))
                                    closed-str)

                         ;; Process SCHEDULED
                         (when scheduled-str
                           (setq item (org-agenda-export--process-timestamp
                                       scheduled-str heading category
                                       priority-char todo-state tags-list
                                       "scheduled" file start-day end-day today))
                           (when item (push item results)))

                         ;; Process DEADLINE
                         (when deadline-str
                           (setq item (org-agenda-export--process-timestamp
                                       deadline-str heading category
                                       priority-char todo-state tags-list
                                       "deadline" file start-day end-day today))
                           (when item (push item results)))

                         ;; Process plain TIMESTAMP property
                         (when (and timestamp-str (not scheduled-str) (not deadline-str))
                           (setq item (org-agenda-export--process-timestamp
                                       timestamp-str heading category
                                       priority-char todo-state tags-list
                                       "timestamp" file start-day end-day today))
                           (when item (push item results)))

                         ;; Scan body for active timestamps (when no property timestamps)
                         (when (and (not scheduled-str) (not deadline-str) (not timestamp-str))
                           (dolist (bts (org-agenda-export--body-timestamps))
                             (setq item (org-agenda-export--process-timestamp
                                         bts heading category
                                         priority-char todo-state tags-list
                                         "timestamp" file start-day end-day today))
                             (when item (push item results)))))))
                   nil nil))
              (error
               (message "Warning: error processing %s: %s" file (error-message-string file-err))))))

        ;; Sort by date, then time
        (setq results (sort results
                            (lambda (a b)
                              (let ((da (cdr (assq 'date a)))
                                    (db (cdr (assq 'date b)))
                                    (ta (cdr (assq 'time a)))
                                    (tb (cdr (assq 'time b))))
                                (if (string= da db)
                                    (string< ta tb)
                                  (string< da db))))))

        ;; Output JSON to stdout
        (princ (json-encode (vconcat results))))

    (error
     (message "org-agenda-export error: %s" (error-message-string err))
     (princ "[]"))))

(defun org-todo-export-json (keywords-str &optional org-dir)
  "Export org TODO items matching KEYWORDS-STR as JSON array to stdout.
KEYWORDS-STR: space- or comma-separated list of TODO keywords (e.g. \"NEXT TODO\").
ORG-DIR: optional org-directory override (expands ~ automatically)."
  (condition-case err
      (let* ((keywords (split-string (or keywords-str "NEXT TODO") "[, ]+" t))
             ;; In batch mode org-todo-keywords only includes TODO/DONE by default.
             ;; Dynamically bind it so org-get-todo-state recognises our keywords
             ;; even in files without a #+TODO: header.
             (org-todo-keywords (list (append '(sequence) keywords '("|" "DONE" "CANCELLED"))))
             (org-dir-expanded (when org-dir
                                 (expand-file-name org-dir)))
             (files (cond
                     ((and org-dir-expanded (file-directory-p org-dir-expanded))
                      (directory-files-recursively org-dir-expanded "\\.org$"))
                     ((bound-and-true-p org-agenda-files)
                      (org-agenda-files t))
                     ((and (bound-and-true-p org-directory)
                           (file-directory-p org-directory))
                      (directory-files-recursively org-directory "\\.org$"))
                     (t '())))
             (results '()))

        (dolist (file files)
          (when (and (file-exists-p file) (file-readable-p file))
            (condition-case file-err
                (with-temp-buffer
                  (insert-file-contents file)
                  (org-mode)
                  (org-map-entries
                   (lambda ()
                     (let* ((todo-state (org-get-todo-state)))
                       (when (and todo-state (member todo-state keywords))
                         (let* ((heading (org-get-heading t t t t))
                                (heading-line (line-number-at-pos (point)))
                                (tags-list (org-get-tags))
                                (priority-char (org-entry-get nil "PRIORITY"))
                                (category (or (org-get-category) ""))
                                (scheduled-str (or (org-entry-get nil "SCHEDULED") ""))
                                (deadline-str (or (org-entry-get nil "DEADLINE") "")))
                           (push `((title . ,heading)
                                   (todoState . ,todo-state)
                                   (category . ,category)
                                   (priority . ,(or priority-char ""))
                                   (tags . ,(vconcat tags-list))
                                   (file . ,file)
                                   (line . ,heading-line)
                                   (scheduled . ,scheduled-str)
                                   (deadline . ,deadline-str))
                                 results)))))
                   nil nil))
              (error
               (message "Warning: error processing %s: %s" file (error-message-string file-err))))))

        ;; Sort by priority (A < B < C < "") then title
        (setq results (sort results
                            (lambda (a b)
                              (let ((pa (or (cdr (assq 'priority a)) ""))
                                    (pb (or (cdr (assq 'priority b)) ""))
                                    (sa (or (cdr (assq 'todoState a)) ""))
                                    (sb (or (cdr (assq 'todoState b)) ""))
                                    (ta (or (cdr (assq 'title a)) ""))
                                    (tb (or (cdr (assq 'title b)) "")))
                                (cond
                                 ((not (string= pa pb))
                                  (cond ((string= pa "A") t)
                                        ((string= pb "A") nil)
                                        ((string= pa "B") t)
                                        ((string= pb "B") nil)
                                        (t (string< pa pb))))
                                 ((not (string= sa sb)) (string< sa sb))
                                 (t (string< ta tb)))))))

        (princ (json-encode (vconcat results))))

    (error
     (message "org-todo-export error: %s" (error-message-string err))
     (princ "[]"))))

(provide 'org-agenda-export)
;;; org-agenda-export.el ends here
