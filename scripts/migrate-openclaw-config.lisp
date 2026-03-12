#!/usr/bin/env sbcl --script
;;;; migrate-openclaw-config.lisp — Convert OpenClaw JSON config to NilClaw Lisp config
;;;;
;;;; Usage:
;;;;   sbcl --script scripts/migrate-openclaw-config.lisp [input.json] [output.lisp]
;;;;
;;;; Defaults:
;;;;   input:  ~/.openclaw/config.json (or ~/.config/openclaw/config.json)
;;;;   output: ~/.nilclaw/init.lisp
;;;;
;;;; The generated file is pure Common Lisp — edit it directly.

(require :asdf)

;;; Minimal JSON reader (no dependencies needed for migration)

(defun skip-ws (s)
  (loop while (and (< (file-position s) (file-length s))
                   (member (peek-char nil s nil) '(#\Space #\Tab #\Newline #\Return)))
        do (read-char s)))

(defun read-json-string (s)
  (assert (char= (read-char s) #\"))
  (with-output-to-string (out)
    (loop for c = (read-char s)
          until (char= c #\")
          do (if (char= c #\\)
                 (let ((escaped (read-char s)))
                   (case escaped
                     (#\n (write-char #\Newline out))
                     (#\t (write-char #\Tab out))
                     (#\\ (write-char #\\ out))
                     (#\" (write-char #\" out))
                     (#\/ (write-char #\/ out))
                     (t (write-char escaped out))))
                 (write-char c out)))))

(defun read-json-value (s)
  (skip-ws s)
  (let ((c (peek-char nil s nil)))
    (cond
      ((null c) nil)
      ((char= c #\") (read-json-string s))
      ((char= c #\{) (read-json-object s))
      ((char= c #\[) (read-json-array s))
      ((char= c #\t) (read-char s) (read-char s) (read-char s) (read-char s) t)
      ((char= c #\f) (dotimes (i 5) (read-char s)) nil)
      ((char= c #\n) (dotimes (i 4) (read-char s)) nil)
      ((or (digit-char-p c) (char= c #\-))
       (let ((num-str (with-output-to-string (out)
                        (loop for ch = (peek-char nil s nil)
                              while (and ch (or (digit-char-p ch) (member ch '(#\. #\- #\+ #\e #\E))))
                              do (write-char (read-char s) out)))))
         (if (find #\. num-str)
             (read-from-string num-str)
             (parse-integer num-str))))
      (t (error "Unexpected character: ~A" c)))))

(defun read-json-object (s)
  (assert (char= (read-char s) #\{))
  (let ((result '()))
    (skip-ws s)
    (when (char= (peek-char nil s) #\})
      (read-char s)
      (return-from read-json-object result))
    (loop
      (skip-ws s)
      (let ((key (read-json-string s)))
        (skip-ws s)
        (assert (char= (read-char s) #\:))
        (let ((val (read-json-value s)))
          (push (cons key val) result)))
      (skip-ws s)
      (let ((c (read-char s)))
        (when (char= c #\}) (return))
        (assert (char= c #\,))))
    (nreverse result)))

(defun read-json-array (s)
  (assert (char= (read-char s) #\[))
  (let ((result '()))
    (skip-ws s)
    (when (char= (peek-char nil s) #\])
      (read-char s)
      (return-from read-json-array result))
    (loop
      (push (read-json-value s) result)
      (skip-ws s)
      (let ((c (read-char s)))
        (when (char= c #\]) (return))
        (assert (char= c #\,))))
    (nreverse result)))

(defun parse-json-file (path)
  (with-open-file (s path :direction :input)
    (read-json-value s)))

;;; Key conversion: "camelCase" / "snake_case" -> :lisp-case

(defun to-lisp-key (s)
  (intern
   (string-upcase
    (with-output-to-string (out)
      (loop for i from 0 below (length s)
            for c = (char s i)
            do (cond
                 ((char= c #\_) (write-char #\- out))
                 ((and (upper-case-p c) (> i 0))
                  (write-char #\- out)
                  (write-char c out))
                 (t (write-char c out))))))
   :keyword))

;;; Convert JSON alist to plist

(defun alist-to-plist (alist)
  (loop for (k . v) in alist
        collect (to-lisp-key k)
        collect (cond
                  ((and (listp v) (consp (car v)) (stringp (caar v)))
                   (alist-to-plist v))
                  (t v))))

;;; Main conversion

(defun convert-config (json-alist)
  "Convert a parsed JSON config to NilClaw s-expression config string."
  (with-output-to-string (s)
    (format s ";;; NilClaw Configuration~%")
    (format s ";;; Migrated from OpenClaw JSON config~%")
    (format s ";;; Edit this file directly — it's pure Common Lisp~%~%")
    (format s "(configure~%")
    (labels ((emit-value (v indent)
               (cond
                 ((null v) (format s "nil"))
                 ((eq v t) (format s "t"))
                 ((stringp v) (format s "~S" v))
                 ((numberp v)
                  (if (floatp v)
                      (format s "~Fd0" v)
                      (format s "~D" v)))
                 ((and (listp v) (keywordp (car v)))
                  ;; Plist
                  (format s "(")
                  (loop for (k val) on v by #'cddr
                        for first = t then nil
                        do (unless first (format s "~%~V@T" (+ indent 1)))
                           (format s "~S " k)
                           (emit-value val (+ indent 2)))
                  (format s ")"))
                 ((listp v)
                  (format s "(")
                  (loop for item in v
                        for first = t then nil
                        do (unless first (format s "~%~V@T" (+ indent 1)))
                           (emit-value item (+ indent 1)))
                  (format s ")"))
                 (t (format s "~S" v))))
             (emit-top (key val)
               (format s "  ~S " key)
               (emit-value val 4)
               (format s "~%")))
      ;; Top-level scalar fields
      (dolist (pair json-alist)
        (let ((key (to-lisp-key (car pair)))
              (val (cdr pair)))
          (cond
            ;; Skip null values
            ((null val))
            ;; Nested objects become plists
            ((and (listp val) (consp (car val)) (stringp (caar val)))
             (emit-top key (alist-to-plist val)))
            ;; Arrays of objects
            ((and (listp val) (consp (car val)) (listp (car val)))
             (emit-top key (mapcar #'alist-to-plist val)))
            ;; Scalars
            (t
             (emit-top key val))))))
    (format s ")~%")))

;;; CLI

(defun main ()
  (let* ((args (uiop:command-line-arguments))
         (input (or (first args)
                    (let ((p1 (merge-pathnames ".openclaw/config.json"
                                              (user-homedir-pathname)))
                          (p2 (merge-pathnames ".config/openclaw/config.json"
                                              (user-homedir-pathname))))
                      (cond
                        ((probe-file p1) (namestring p1))
                        ((probe-file p2) (namestring p2))
                        (t (format *error-output*
                                   "Error: No OpenClaw config found. Pass path as argument.~%")
                           (uiop:quit 1))))))
         (output (or (second args)
                     (namestring (merge-pathnames ".nilclaw/init.lisp"
                                                 (user-homedir-pathname))))))
    (format t "Reading OpenClaw config: ~A~%" input)
    (let* ((json (parse-json-file input))
           (result (convert-config json)))
      ;; Ensure output directory exists
      (ensure-directories-exist (pathname output))
      (with-open-file (s output :direction :output
                                :if-exists :supersede
                                :if-does-not-exist :create)
        (write-string result s))
      (format t "Written NilClaw config: ~A~%~%" output)
      (format t "Your config is now pure Common Lisp. Edit it directly!~%")
      (format t "NilClaw searches: ~/.nilclaw/init.lisp, ~/.nilclaw/config.lisp~%"))))

(main)
