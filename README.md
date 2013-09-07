cl-pbriak
=========

Common Lisp Driver for riak using Protocol Buffers Client (PBC) interface


This is my attempt to write a Common Lisp driver for the
key-value-store [Riak](http://basho.com/riak/) using their [Protocol
Buffers Client (PBC) interface](http://docs.basho.com/riak/latest/dev/references/protocol-buffers/).

It should be significantly faster than the HTTP-interface.


Installation
------------

If you use [Quicklisp](http://www.quicklisp.org/beta/), put it into
~/quicklisp/local-projects/:

    cd ~/quicklisp/local-projects/
    git clone https://github.com/okflo/cl-pbriak.git 

Load via quicklisp

    (ql:quickload :cl-pbriak)


Example
-------





