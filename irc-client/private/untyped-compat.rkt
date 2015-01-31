#lang racket/base

(provide untyped-async-channel-get)

(require racket/async-channel)

(define (untyped-async-channel-get ac)
  (async-channel-get ac))
