#lang typed/racket/base

(require/typed/provide
 irc
 [#:struct irc-message ([prefix : (Option String)]
                        [command : String]
                        [parameters : (Listof String)]
                        [content : String])]
 [#:opaque irc-connection irc-connection?]
 [irc-connect (String Nonnegative-Integer String String String
                      [#:ssl (U Boolean 'auto 'sslv2-or-v3 'sslv2 'sslv3 'tls 'tls11 'tls12)]
                      [#:return-eof Boolean]
                      -> (values irc-connection (Evtof Semaphore)))]
 [irc-connection-incoming (irc-connection -> (Async-Channelof (U irc-message EOF)))]
 [irc-join-channel (irc-connection String -> Void)]
 [irc-part-channel (irc-connection String -> Void)]
 [irc-send-message (irc-connection String String -> Void)]
 [irc-send-notice (irc-connection String String -> Void)]
 [irc-get-connection (String Nonnegative-Integer [#:return-eof Boolean] -> irc-connection)]
 [irc-set-nick (irc-connection String -> Void)]
 [irc-set-user-info (irc-connection String String -> Void)]
 [irc-quit ((irc-connection) (String) . ->* . Void)]
 [irc-send-command (irc-connection String String * -> Void)])
