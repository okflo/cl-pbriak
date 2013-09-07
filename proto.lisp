(in-package :riak)

(proto:define-schema riak
    (:package riak
              :lisp-package :riak)

  (proto:define-message rpb-error-resp
      (:conc-name "")
    (errmsg  :type string)
    (errcode  :type proto:uint32))

  (proto:define-message rpb-pair
      (:conc-name "")
    (key :type string)
    (value :type (or null string)))

  (proto:define-message rpb-link
      (:conc-name "")
    (bucket :type (or null string))
    (key :type (or null string))
    (tag :type (or null string)))
  
  (proto:define-message rpb-content
      (:conc-name "")
    (value :type string)
    (content-type :type (or null string))
    (charset :type (or null string))
    (content-encoding :type (or null string))
    (vtag :type (or null string))
    (links  :type (proto:list-of rpb-link))
    (last-mod :type (or null proto:uint32))
    (last-mod-usecs :type (or null proto:uint32))
    (usermeta :type (proto:list-of rpb-pair))
    (indexes :type (proto:list-of rpb-pair))
    (deleted :type (or null boolean)))

  ;; RpbGetReq
  
  (proto:define-message rpb-get-req
      (:conc-name "")
    (bucket :type string)
    (key :type string)
    (r :type (or proto:uint32 null))
    (pr :type (or proto:uint32 null))
    (basic-quorum :type (or boolean null))
    (notfound-ok :type (or boolean null))
    (if-modified :type (or string null))
    (head :type (or boolean null))
    (deletedvclock :type (or boolean null)))
  
  (proto:define-message rpb-get-resp
      (:conc-name "")
    (content :type (proto:list-of rpb-content))
    (vclock :type (or proto:byte-vector null))
    (unchanged :type (or boolean null)))

  ;; RpbPutReq

  (proto:define-message rpb-put-req
      (:conc-name "")
    (bucket :type string)
    (key :type (or null string))
    (vclock :type (or null proto:byte-vector))
    (content :type rpb-content)
    (w :type (or null proto:uint32))
    (dw :type (or null proto:uint32))
    (return-body :type (or null boolean))
    (pw :type (or null proto:uint32))
    (if-not-modified :type (or null boolean))
    (if-none-match :type (or null boolean))
    (return-head :type (or null boolean))
    (timeout :type (or null proto:uint32))
    (asis :type (or null boolean))
    (sloppy-quorum :type (or null boolean))
    (n-val :type (or null proto:uint32)))

  (proto:define-message rpb-put-resp
      (:conc-name "")
    (content :type (proto:list-of rpb-content))
    (vclock :type (or null proto:byte-vector))
    (key :type (or null proto:byte-vector)))

  ;; RpbDelReq

  (proto:define-message rpb-del-req
      (:conc-name "")
    (bucket :type string)
    (key :type string)
    (rw :type (or null proto:uint32))
    (vclock :type (or null proto:byte-vector))
    (r :type (or null proto:uint32))
    (w :type (or null proto:uint32))
    (pr :type (or null proto:uint32))
    (pw :type (or null proto:uint32))
    (dw :type (or null proto:uint32))
    (timeout :type (or null proto:uint32))
    (sloppy-quorum :type (or null boolean))
    (n-val :type (or null proto:uint32)))

  ;; RpbListBuckets

  (proto:define-message rpb-list-buckets-req
      (:conc-name "")
    (timeout :type (or null proto:uint32))
    (stream  :type (or null boolean)))
  (proto:define-message rpb-list-buckets-resp
      (:conc-name "")
    (buckets :type (proto:list-of string))
    (done :type (or null boolean)))
  
  ;;RpbListKeys
  
  (proto:define-message rpb-list-keys-req
      (:conc-name "")
    (bucket :type string)
    (timeout :type (or null proto:uint32)))
  (proto:define-message rpb-list-keys-resp
      (:conc-name "")
    (keys :type (proto:list-of string))
    (done :type (or null boolean)))

  ;;RpbGetClientId

  (proto:define-message rpb-get-client-id-resp
      (:conc-name "")
    (client-id :type protobufs:byte-vector))


  (proto:define-message rpb-get-server-info-resp
      (:conc-name "")
    (node :type (or null string))
    (server-version :type (or null string))))
