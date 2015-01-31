#lang typed/racket/base

(require (for-syntax racket/base)
         racket/match
         racket/list
         typed/racket/async-channel
         (prefix-in irc: "private/typed/irc.rkt"))

(provide (struct-out IrcConnection)
         (struct-out IrcUser)
         (struct-out IrcMessage)
         (struct-out IrcMessage-Message)
         (struct-out IrcMessage-ChatMessage)
         (struct-out IrcMessage-ActionMessage)
         (struct-out IrcMessage-Notice)
         (struct-out IrcMessage-Join)
         (struct-out IrcMessage-Part)
         irc-connect
         irc-join-channel!
         irc-part-channel!
         irc-send-message!
         irc-send-action!
         irc-send-notice!
         irc-set-nick!
         irc-set-user-info!
         irc-quit!
         irc-send!
         irc-recv!)

(struct IrcConnection ([internal-connection : irc:irc-connection]) #:transparent)
(struct IrcUser ([nick : String] [username : String] [host : String]) #:transparent)

(struct IrcMessage ([internal-message : irc:irc-message]) #:transparent)
(struct IrcMessage-Message IrcMessage ([sender : IrcUser]
                                       [recipient : String]
                                       [content : String])
  #:transparent)
(struct IrcMessage-ChatMessage IrcMessage-Message () #:transparent)
(struct IrcMessage-ActionMessage IrcMessage-Message () #:transparent)
(struct IrcMessage-Notice IrcMessage ([sender : IrcUser]
                                      [recipient : String]
                                      [content : String]) #:transparent)
(struct IrcMessage-Join IrcMessage ([user : IrcUser] [channel : String]) #:transparent)
(struct IrcMessage-Part IrcMessage ([user : IrcUser] [channel : String] [reason : String]) #:transparent)

(: irc-connect (String Nonnegative-Integer String String String
                       -> (values IrcConnection (Evtof Semaphore))))
(define (irc-connect server port nick username real-name)
  (let-values ([(connection event) (irc:irc-connect server port nick username real-name)])
    (values (IrcConnection connection) event)))

(: irc-join-channel! (IrcConnection String -> Void))
(define (irc-join-channel! connection channel)
  (irc:irc-join-channel (IrcConnection-internal-connection connection) channel))

(: irc-part-channel! (IrcConnection String -> Void))
(define (irc-part-channel! connection channel)
  (irc:irc-part-channel (IrcConnection-internal-connection connection) channel))

(: irc-send-message! (IrcConnection String String -> Void))
(define (irc-send-message! connection target message)
  (irc:irc-send-message (IrcConnection-internal-connection connection) target message))

(: irc-send-action! (IrcConnection String String -> Void))
(define (irc-send-action! connection target message)
  (irc:irc-send-command (IrcConnection-internal-connection connection) "PRIVMSG" target
                        (format ":\u0001ACTION ~a\u0001" message)))

(: irc-send-notice! (IrcConnection String String -> Void))
(define (irc-send-notice! connection target message)
  (irc:irc-send-notice (IrcConnection-internal-connection connection) target message))

(: irc-set-nick! (IrcConnection String -> Void))
(define (irc-set-nick! connection nick)
  (irc:irc-set-nick (IrcConnection-internal-connection connection) nick))

(: irc-set-user-info! (IrcConnection String String -> Void))
(define (irc-set-user-info! connection username real-name)
  (irc:irc-set-user-info (IrcConnection-internal-connection connection) username real-name))

(: irc-quit! ((IrcConnection) (String) . ->* . Void))
(define (irc-quit! connection [message ""])
  (irc:irc-quit (IrcConnection-internal-connection connection) message))

(: irc-send! (IrcConnection String String * -> Void))
(define (irc-send! connection command . args)
  (apply irc:irc-send-command (IrcConnection-internal-connection connection) command args))

(: irc-recv! (IrcConnection -> IrcMessage))
(define (irc-recv! connection)
  (define message
    (async-channel-get (irc:irc-connection-incoming (IrcConnection-internal-connection connection))))
  (when (eof-object? message)
    (error "irc connection closed"))
  (parse-irc-message message))

; parses an irc-message instance to one of the IrcMessage instances
(define (parse-irc-message [message : irc:irc-message]) : IrcMessage
  (match message
    [(irc:irc-message (irc-user-prefix user) "PRIVMSG" (list recipient content) _)
     (parse-irc-privmsg message user recipient content)]
    [(irc:irc-message (irc-user-prefix user) "NOTICE" (list recipient content) _)
     (IrcMessage-Notice message user recipient content)]
    [(irc:irc-message (irc-user-prefix user) "JOIN" (list channel) _)
     (IrcMessage-Join message user channel)]
    [(irc:irc-message (irc-user-prefix user) "PART" (list channel reason) _)
     (IrcMessage-Part message user channel reason)]
    [_ (IrcMessage message)]))

; parses an IRC PRIVMSG to handle CTCP actions
(: parse-irc-privmsg (irc:irc-message IrcUser String String -> IrcMessage))
(define (parse-irc-privmsg message user recipient content)
  (match content
    [(pregexp #px"^\u0001ACTION ([^\u0001]*)\u0001" (list _ (? string? action-content)))
     (IrcMessage-ActionMessage message user recipient action-content)]
    [_
     (IrcMessage-ChatMessage message user recipient content)]))

; matches and extracts data from an irc user prefix
(define-match-expander irc-prefix
  (λ (stx)
    (syntax-case stx ()
      [(_ nick username host)
       #'(pregexp #px"^([^!]+)!([^@]+)@(.+)$"
                  (list _ (? string? nick) (? string? username) (? string? host)))])))

; like irc-prefix, but stores the result in an IrcUser instance
(define-match-expander irc-user-prefix
  (λ (stx)
    (syntax-case stx ()
      [(_ user)
       #'(app (match-lambda
                [(irc-prefix nick username host) (IrcUser nick username host)]
                [_ #f])
              (? IrcUser? user))])))

(define (print-irc-message [msg : IrcMessage])
  (match msg
    [(IrcMessage-ChatMessage _ (IrcUser nick _ _) recipient content)
     (printf "~a -> ~a :: ~a~n" nick recipient content)]
    [(IrcMessage-ActionMessage _ (IrcUser nick _ _) recipient content)
     (printf "-> ~a :: ~a ~a~n" recipient nick content)]
    [(IrcMessage-Join _ (IrcUser nick user host) channel)
     (printf "~a (~a@~a) joined ~a~n" nick user host channel)]
    [(IrcMessage message) (printf "~a~n" message)]))
