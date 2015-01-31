#lang info

(define collection 'multi)

(define version "0.1.0")

(define deps
  '("base"
    "irc"
    "typed-racket-lib"
    "typed-racket-more"
    "unstable-contract-lib"))
(define implies
  '("irc"))
(define build-deps
  '("racket-doc"
    "scribble-lib"
    "typed-racket-doc"))
