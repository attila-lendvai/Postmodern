;;;; -*- Mode: LISP; Syntax: Ansi-Common-Lisp; Base: 10; Package: CL-POSTGRES; -*-
(in-package :cl-postgres)

;; These are used to synthesize reader and writer names for integer
;; reading/writing functions when the amount of bytes and the
;; signedness is known. Both the macro that creates the functions and
;; some macros that use them create names this way.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun integer-reader-name (bytes signed)
    (intern (with-standard-io-syntax
              (format nil "~a~a~a~a" '#:read- (if signed "" '#:u)
                      '#:int bytes))))
  (defun integer-writer-name (bytes signed)
    (intern (with-standard-io-syntax
              (format nil "~a~a~a~a" '#:write- (if signed "" '#:u)
                      '#:int bytes)))))

(defmacro integer-reader (bytes)
  "Create a function to read integers from a binary stream."
  (let ((bits (* bytes 8)))
    (labels ((return-form (signed)
               (if signed
                   `(if (logbitp ,(1- bits) result)
                        (dpb result (byte ,(1- bits) 0) -1)
                        result)
                   `result))
             (generate-reader (signed)
               `(defun ,(integer-reader-name bytes signed) (socket)
                  (declare (type stream socket)
                           #.*optimize*)
                  ,(if (= bytes 1)
                       `(let ((result (the (unsigned-byte 8) (read-byte socket))))
                          (declare (type (unsigned-byte 8) result))
                          ,(return-form signed))
                       `(let ((result 0))
                          (declare (type (unsigned-byte ,bits) result))
                          ,@(loop :for byte :from (1- bytes) :downto 0
                                  :collect `(setf (ldb (byte 8 ,(* 8 byte))
                                                       result)
                                                  (the (unsigned-byte 8)
                                                       (read-byte socket))))
                          ,(return-form signed))))))
      `(progn
         ;; This causes weird errors on SBCL in some circumstances. Disabled for now.
         ;;         (declaim (inline ,(integer-reader-name bytes t)
         ;;                          ,(integer-reader-name bytes nil)))
         (declaim (ftype (function (t) (signed-byte ,bits))
                         ,(integer-reader-name bytes t)))
         ,(generate-reader t)
         (declaim (ftype (function (t) (unsigned-byte ,bits))
                         ,(integer-reader-name bytes nil)))
         ,(generate-reader nil)))))

(defmacro integer-writer (bytes)
  "Create a function to write integers to a binary stream."
  (let ((bits (* 8 bytes)))
    `(progn
       (declaim (inline ,(integer-writer-name bytes t)
                        ,(integer-writer-name bytes nil)))
       (defun ,(integer-writer-name bytes nil) (socket value)
         (declare (type stream socket)
                  (type (unsigned-byte ,bits) value)
                  #.*optimize*)
         ,@(if (= bytes 1)
               `((write-byte value socket))
               (loop :for byte :from (1- bytes) :downto 0
                     :collect `(write-byte (ldb (byte 8 ,(* byte 8)) value)
                                           socket)))
         (values))
       (defun ,(integer-writer-name bytes t) (socket value)
         (declare (type stream socket)
                  (type (signed-byte ,bits) value)
                  #.*optimize*)
         ,@(if (= bytes 1)
               `((write-byte (ldb (byte 8 0) value) socket))
               (loop :for byte :from (1- bytes) :downto 0
                     :collect `(write-byte (ldb (byte 8 ,(* byte 8)) value)
                                           socket)))
         (values)))))

;; All the instances of the above that we need.

(integer-reader 1)
(integer-reader 2)
(integer-reader 4)
(integer-reader 8)

(integer-writer 1)
(integer-writer 2)
(integer-writer 4)

(defun write-bytes (socket bytes)
  "Write a byte-array to a stream."
  (declare (type stream socket)
           (type (simple-array (unsigned-byte 8)) bytes)
           #.*optimize*)
  (write-sequence bytes socket))

(defun write-str (socket string)
  "Write a null-terminated string to a stream \(encoding it when UTF-8
support is enabled.)."
  (declare (type stream socket)
           (type string string)
           #.*optimize*)
  (enc-write-string string socket)
  (write-uint1 socket 0))

(declaim (ftype (function (t unsigned-byte)
                          (simple-array (unsigned-byte 8) (*)))
                read-bytes))
(defun read-bytes (socket length)
  "Read a byte array of the given length from a stream."
  (declare (type stream socket)
           (type fixnum length)
           #.*optimize*)
  (let ((result (make-array length :element-type '(unsigned-byte 8))))
    (read-sequence result socket)
    result))

(declaim (ftype (function (t) string) read-str))
(defun read-str (socket)
  "Read a null-terminated string from a stream. Takes care of encoding
when UTF-8 support is enabled."
  (declare (type stream socket)
           #.*optimize*)
  (enc-read-string socket :null-terminated t))

(declaim (ftype (function (t) string) read-simple-str))
(defun read-simple-str (socket)
  "Read a null-terminated string from a stream. Interprets it as ASCII."
  (declare (type stream socket)
           #.*optimize*)
  (with-output-to-string (out)
    (loop :for b := (read-byte socket nil 0) :do
      (cond ((eq b 0) (return))
            ((< b 128) (write-char (code-char b) out))))))

(defun skip-bytes (socket length)
  "Skip a given number of bytes in a binary stream."
  (declare (type stream socket)
           (type (unsigned-byte 32) length)
           #.*optimize*)
  (dotimes (i length)
    (read-byte socket)))

(defun skip-str (socket)
  "Skip a null-terminated string."
  (declare (type stream socket)
           #.*optimize*)
  (loop :for char :of-type fixnum = (read-byte socket)
        :until (zerop char)))

(defun ensure-socket-is-closed (socket &key abort)
  (when (open-stream-p socket)
    (handler-case
        (close socket :abort abort)
      (error (error)
        (warn "Ignoring the error which happened while trying to close
 PostgreSQL socket: ~A" error)))))

;; a mostly verbatim copy from alexandria
(defun copy-stream (input output &key (element-type (stream-element-type input))
                    (buffer-size 4096)
                    (buffer (make-array buffer-size :element-type element-type))
                    (start 0) end
                    finish-output)
  "Reads data from INPUT and writes it to OUTPUT. Both INPUT and OUTPUT must
be streams, they will be passed to READ-SEQUENCE and WRITE-SEQUENCE and must have
compatible element-types."
  (check-type start (integer 0))
  (check-type end (or null (integer 0)))
  (check-type buffer-size (integer 1))
  (when (and end
             (< end start))
    (error "END is smaller than START in ~S" 'copy-stream))
  (let ((output-position 0)
        (input-position 0))
    (unless (zerop start)
      ;; FIXME add platform specific optimization to skip seekable streams
      (loop while (< input-position start)
            do (let ((n (read-sequence buffer input
                                       :end (min (length buffer)
                                                 (- start input-position)))))
                 (when (zerop n)
                   (error "~@<Could not read enough bytes from the input to fulfill ~
                           the :START ~S requirement in ~S.~:@>" 'copy-stream start))
                 (incf input-position n))))
    (assert (= input-position start))
    (loop while (or (null end) (< input-position end))
          do (let ((n (read-sequence buffer input
                                     :end (when end
                                            (min (length buffer)
                                                 (- end input-position))))))
               (when (zerop n)
                 (if end
                     (error "~@<Could not read enough bytes from the input to fulfill ~
                          the :END ~S requirement in ~S.~:@>" 'copy-stream end)
                     (return)))
               (incf input-position n)
               (write-sequence buffer output :end n)
               (incf output-position n)))
    (when finish-output
      (finish-output output))
    output-position))
