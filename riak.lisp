(in-package :riak)

;;; Message Codes
;; from http://docs.basho.com/riak/latest/dev/references/protocol-buffers/
(defconstant +rpb-error-resp+ 0)
(defconstant +rpb-ping-req+ 1)
(defconstant +rpb-ping-resp+ 2)
(defconstant +rpb-get-client-id-req+ 3)
(defconstant +rpb-get-client-id-resp+ 4)
(defconstant +rpb-set-client-id-req+ 5)
(defconstant +rpb-set-client-id-resp+ 6)
(defconstant +rpb-get-server-info-req+ 7)
(defconstant +rpb-get-server-info-resp+ 8)
(defconstant +rpb-get-req+ 9)
(defconstant +rpb-get-resp+ 10)
(defconstant +rpb-put-req+ 11)
(defconstant +rpb-put-resp+ 12)
(defconstant +rpb-del-req+ 13)
(defconstant +rpb-del-resp+ 14)
(defconstant +rpb-list-bucket-req+ 15)
(defconstant +rpb-list-bucket-resp+ 16)
(defconstant +rpb-list-keys-req+ 17)
(defconstant +rpb-list-keys-resp+ 18)
(defconstant +rpb-get-bucket-req+ 19)
(defconstant +rpb-get-bucket-resp+ 20)
(defconstant +rpb-set-bucket-req+ 21)
(defconstant +rpb-set-bucket-resp+ 22)
(defconstant +rpb-map-red-req+ 23)
(defconstant +rpb-map-red-resp+ 24)
(defconstant +rpb-index-req+ 25)
(defconstant +rpb-index-resp+ 26)
(defconstant +rpb-search-query-req+ 27)
(defconstant +rpb-search-query-resp+ 28)

(defstruct riak-connection
  socket
  socket-stream
  active)

(defvar *default-riak-connection*
  nil)

(defvar *riak-connection-pool*
  nil)

(defvar *connection-pool-lock*
  (bordeaux-threads:make-lock "connection-pool"))

(defun acquire-connection-from-connection-pool ()
  (bordeaux-threads:with-lock-held (*connection-pool-lock*) 
    (let ((connection (pop *riak-connection-pool*)))
      (unless connection
        (setf connection (open-connection)))
      connection)))

(defun free-connection-to-connection-pool (connection)
  (bordeaux-threads:with-lock-held (*connection-pool-lock*) 
    (push connection *riak-connection-pool*)))

(defun open-connection (&key (host "localhost") (port 8087))
  (let* ((socket (usocket:socket-connect host port :element-type '(unsigned-byte 8)))
         (socket-stream (usocket:socket-stream socket)))
    (make-riak-connection :socket socket
                          :socket-stream socket-stream
                          :active nil)))

(defun close-connection (&key (riak-connection *default-riak-connection*))
  (usocket:socket-close (riak-connection-socket riak-connection)))

(defun open-default-riak-connection (&key (host "localhost") (port 8087))
  (setf *default-riak-connection*
        (open-connection :host host :port port)))

(defmacro with-store ((&key (host "localhost") (port 8087)) &body body)
  `(let ((*default-riak-connection* (acquire-connection-from-connection-pool)))
     ,@body
     (free-connection-to-connection-pool *default-riak-connection*)))

(defun integer-to-byte-array (n &key (number-of-byte 3))
  (let ((output (make-array (list (1+ number-of-byte)) :element-type '(unsigned-byte 8))))
    (loop for i from number-of-byte downto 0
       do
         (setf (aref output (- number-of-byte i)) (ldb (byte 8 (* i 8)) n)))
    output))

(defun byte-array-to-integer (array &key (number-of-byte 3))
  (let ((output 0))
    (loop for i from number-of-byte downto 0
       do
         (setf (ldb (byte 8 (* i 8)) output) (aref array (- number-of-byte i))))
    output))

(defstruct message
  length
  code
  body)

(defun send-message-to-socket-stream (message socket-stream)
  (map
   'nil
   (lambda (byte)
     (write-byte byte socket-stream))
   (concatenate 'vector
                (message-length message)
                (make-array '(1) 
                            :element-type '(unsigned-byte 8) 
                            :initial-element (message-code message))
                (message-body message)))
  (force-output socket-stream))

(defun read-n-bytes-from-socket-stream (n socket-stream)
  (let ((output (make-array (list n) :element-type '(unsigned-byte 8))))
    (loop for i from 0 to (1- n)
       do
         (setf (aref output i) (read-byte socket-stream))
         (format t "read: ~A~%" (aref output i)))
    output))

(defun receive-message-from-socket-stream (socket-stream)
  (let* ((length (byte-array-to-integer 
                  (read-n-bytes-from-socket-stream 4 socket-stream)))
         (code (aref (read-n-bytes-from-socket-stream 1 socket-stream) 0))
         (message (read-n-bytes-from-socket-stream (1- length) socket-stream)))
    (values code message)))

(eval-when (:compile-toplevel :load-toplevel) 
  (defun make-keyword (keyword)
    (intern (symbol-name keyword) :keyword)))

(defmacro def-rpb-command (name required-arguments optional-arguments
                           req-code resp-code 
                           &optional rpb-object-name rpb-response-object-name 
                             handle-response)
  `(defun ,name (,@(mapcan
                    (lambda (arg)
                      (if (atom arg)
                          (list arg)
                          (list (car arg))))
                    required-arguments) &key ,@optional-arguments
                                          (riak-connection *default-riak-connection*))
     (let ((message 
            (make-message :length nil
                          :code ,req-code
                          :body ,(when rpb-object-name
                                       `(proto:serialize-object-to-bytes
                                         (make-instance ',rpb-object-name
                                                        ,@(mapcan 
                                                           (lambda (i) 
                                                             (if (atom i) 
                                                                 (list (make-keyword i) i)
                                                                 (second i)))
                                                           (append required-arguments
                                                                   optional-arguments)))
                                         ',rpb-object-name)))))
       (setf (message-length message) (integer-to-byte-array
                                       (1+ (length (message-body message)))))
       (send-message-to-socket-stream message (riak-connection-socket-stream riak-connection))
       (multiple-value-bind (code message)
           (receive-message-from-socket-stream (riak-connection-socket-stream riak-connection))
         (declare (ignorable message))
         (format t "message-code: ~A" code)
         (cond ((= code ,resp-code)
                ,(cond ((and rpb-response-object-name handle-response)
                        `(,handle-response (proto:deserialize-object-from-bytes
                                            ',rpb-response-object-name
                                            message)))
                       (handle-response
                        `(,handle-response message))
                       (t `(values))))
               ((= code 0)
                (let ((error-resp (proto:deserialize-object-from-bytes
                                   'rpb-error-resp
                                   message)))
                  (error (errmsg error-resp)))
                ))))))

(def-rpb-command ping 
    () ()
    +rpb-ping-req+ +rpb-ping-resp+ 
    nil nil
    (lambda (response)
      (declare (ignore response))
      "pong"))

(def-rpb-command rput
    (bucket key (value (:content (make-instance 'rpb-content :value value))))
  (vclock w dw return-body pw if-not-modified if-none-match return-head timeout asis sloppy-quorum n-val)
  +rpb-put-req+ +rpb-put-resp+
  rpb-put-req rpb-put-resp
  (lambda (response)
    (values (content response)
            (vclock response))))

(def-rpb-command rget 
    (bucket key) (r pr basic-quorum notfound-ok if-modified head deletedvclock) 
    +rpb-get-req+ +rpb-get-resp+
    rpb-get-req rpb-get-resp
    (lambda (response)
      (when (content response)
        (values (value (car (content response)))
                (content-type (car (content response)))))))

(def-rpb-command rdel
    (bucket key) (rw vclock r w pr pw dw timeout sloppy-quorum n-val)
    +rpb-del-req+ +rpb-del-resp+
    rpb-del-req)

(def-rpb-command list-buckets
    () (timeout stream)
    +rpb-list-bucket-req+ +rpb-list-bucket-resp+
    rpb-list-buckets-req rpb-list-buckets-resp
    (lambda (response)
      (buckets response)))

(def-rpb-command list-keys
    (bucket) (timeout)
    +rpb-list-keys-req+ +rpb-list-keys-resp+
    rpb-list-keys-req rpb-list-keys-resp
    (lambda (response)
      (let ((output (keys response)))
        (unless (and (slot-boundp response 'done) (done response))
          (loop 
             do
               (multiple-value-bind (lcode lmessage) 
                   (receive-message-from-socket-stream (riak-connection-socket-stream *default-riak-connection*))
                 (declare (ignore lcode))
                 (setf lmessage (proto:deserialize-object-from-bytes
                                 'rpb-list-keys-resp
                                 lmessage))
                 (if (and (slot-boundp lmessage 'done) (done lmessage))
                     (progn
                       (setf output (append output (keys lmessage)))
                       (return))
                     (setf output (append output (keys lmessage)))))))
        output)))

(def-rpb-command get-client-id
    () ()
    +rpb-get-client-id-req+ +rpb-get-client-id-resp+
    nil rpb-get-client-id-resp
    (lambda (response)
      (client-id response)))

(def-rpb-command get-server-info
    () ()
    +rpb-get-server-info-req+ +rpb-get-server-info-resp+
    nil rpb-get-server-info-resp
    (lambda (response)
      (values (node response)
              (server-version response))))

(defun test-populate (n)
  (loop for i from 1 to n
     do
       (rput "teste"
             (format nil "~A" n)
             (format nil "Das ist ~A" n))))

(defun teste-parallel (n)
  (loop for i from 1 to n
     do
       (multput "teste2"
                (format nil "~A" i)
                (format nil "Das ist ~A" i))
       
       )
  (commit))


(let ((buffer nil))
  (defun multput (bucket key value)
    (push (list bucket key value) buffer)
    (when (> (length buffer) 1000)
      (commit)))
  (defun commit ()
    (lparallel:pmap nil
                    (lambda (x)
                      (rput (first x)
                            (second x)
                            (third x)))
                    buffer)
    (setf buffer nil))
  (defun show ()
    (print buffer)))
