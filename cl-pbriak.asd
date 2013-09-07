(in-package #:cl)

(asdf:defsystem :cl-pbriak
  :version 0.1
  :depends-on (:usocket :bordeaux-threads :cl-protobufs)
  :components ((:file "package")
               (:file "proto"
                      :depends-on ("package"))
               (:file "riak"
                      :depends-on ("proto"))))
