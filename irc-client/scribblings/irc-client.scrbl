#lang scribble/manual

@(require (for-label typed/racket/base
                     racket/match
                     irc-client
                     (prefix-in irc: irc)))

@title{IRC Client: High-Level IRC API}

@author{@author+email["Alexis King" "lexi.lambda@gmail.com"]}

@defmodule[irc-client]

The @racketmodname[irc-client] library is a wrapper build on top of the @racketmodname[irc] library.
It provides a higher-level interface compared to @racketmodname[irc]'s comparatively low-level
constructs.

It is implemented in Typed Racket and is fully compatible with typed programs, though it should work
with untyped programs as well.

@section{Overview and Examples}

This library provides a set of constructs for interacting with IRC servers in Racket. To connect to
a server, use @racket[irc-connect].

@(racketblock
  (define-values (conn ready-evt) (irc-connect "irc.example.com" 6697
                                               "nickname" "username" "Real Name"
                                               #:ssl 'auto))
  (sync ready-evt))

The second value returned from @racket[irc-connect] is a
@tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{synchronizable event} that becomes
@tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{ready for synchronization} once a
connection to the IRC server has been established.

The first value returned is an @racket[IrcConnection] object which can be used with other
@racketmodname[irc-client] functions to interact with the IRC server. For example, to join an IRC
channel, once would issue the following command:

@(racketblock
  (irc-join-channel! conn "#racket"))

The primary difference between @racketmodname[irc-client] and @racketmodname[irc] is how recieving
messages from the server works. In @racketmodname[irc-client], the @racket[irc-recv!] function returns
an instance of the @racket[IrcMessage] struct. This is intended to be used with @racket[match] to
handle various types of commands. For example, to handle chat and action messages separately, one
would use the following @racket[match] structure:

@(racketblock
  (let loop ()
    (match (irc-recv! conn)
      [(IrcMessage-ChatMessage _ (IrcUser nick _ _) recipient content)
       (printf "(~a) <~a> ~a\n" recipient nick content)]
      [(IrcMessage-ActionMessage _ (IrcUser nick _ _) recipient content)
       (printf "(~a) * ~a ~a\n" recipient nick content)]
      [_ (void)])
    (loop)))

@section{Managing IRC Connections}

@defproc[(irc-connect [host String] [port Nonnegative-Integer] [nick String]
                      [username String] [real-name String])
         (values IrcConnection (Evtof Semaphore))]{
Establishes a connection to an IRC server at the given @racket[host] on the given @racket[port]. The
@tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{synchronizable event} returned becomes
@tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{ready for synchronization} once a
connection to the server has been established, at which point additional client commands can be
issued.}

@defproc[(irc-join-channel! [connection IrcConnection] [channel String]) Void]{
Joins the provided IRC @racket[channel] on the server connected to via @racket[connection].}

@defproc[(irc-part-channel! [connection IrcConnection] [channel String]) Void]{
Leaves the provided IRC @racket[channel] on the server connected to via @racket[connection].}

@defproc[(irc-send-message! [connection IrcConnection] [target String] [message String]) Void]{
Sends the given @racket[message] to @racket[target], which may be an IRC channel or the nickname of a
user currently connected to IRC. If @racket[target] represents a channel, it should be prefixed with
the usual @code["\"#\""] used by IRC to distinguish channels.}

@defproc[(irc-send-action! [connection IrcConnection] [target String] [message String]) Void]{
Sends the given @racket[message] to @racket[target]. Similar to @racket[irc-send-message!], but it
sends the message formatted as a CTCP ACTION command. Most IRC clients implement this functionality
via a @code{/me} command and display action messages differently from ordinary messages.}

@defproc[(irc-send-notice! [connection IrcConnection] [target String] [message String]) Void]{
Sends the given @racket[message] to @racket[target]. Similar to @racket[irc-send-message!], but sends
the message as an IRC @code{NOTICE} rather than a @code{PRIVMSG}.}

@defproc[(irc-set-nick! [connection IrcConnection] [nick String]) Void]{
Sets the nickname of the client connected via @racket[connection] to @racket[nick].}

@defproc[(irc-set-user-info! [connection IrcConnection] [username String] [real-name String]) Void]{
Sets the username and real name of the client connected via @racket[connection] to @racket[username]
and @racket[real-name], respectively.}

@defproc[(irc-quit! [connection IrcConnection] [message String ""]) Void]{
Disconnects from the IRC server. If @racket[message] is provided, a custom quit reason is supplied,
otherwise the quit reason is left empty.}

@defproc[(irc-send! [connection IrcConnection] [command String] [args String] ...) Void]{
Sends a raw command to the IRC server. Use this function if you need to send something to the server
not supported by any of the higher-level commands.}

@defproc[(irc-recv! [connection IrcConnection]) IrcMessage]{
Recieves a message from the IRC server as an instance of @racket[IrcMessage]. Messages are internally
queued, so if a message is available, it will be returned immediately. Otherwise, this function will
block until a message arrives.

If the connection is closed, an @racket[exn:fail] will be raised.}

@defproc[(irc-recv-evt [connection IrcConnection]) (Evtof IrcMessage)]{
Returns a synchronizable event that waits for an incoming message from the connection. The synchronization
result is the @racket[IrcMessage] recieved.

If the connection is closed, an @racket[exn:fail] will be raised.}

@section{Structure Types}

@defstruct*[IrcConnection ([internal-connection irc:irc-connection?]) #:transparent]{
Represents a connection an IRC server. The @racket[internal-connection] field allows access to the
underlying @racketmodname[irc] connection object, if needed for whatever reason.}

@defstruct*[IrcUser ([nick String] [username String] [host String]) #:transparent]{
Represents an IRC user, and is included in various @racket[IrcMessage] subtypes.}

@subsection{Message Types}

@defstruct*[IrcMessage ([internal-message irc:irc-message?]) #:transparent]{
The supertype for all IRC message structures. The @racket[internal-message] field allows access to the
underlying @racketmodname[irc] message object, if needed for whatever reason.}

@defstruct*[(IrcMessage-Message IrcMessage) ([sender IrcUser] [recipient String] [content String])
             #:transparent]{
Represents an ordinary message sent from the IRC server from the given @racket[sender] to the given
@racket[recipient], which may be a nickname (the client's nickname, in which case it is a private
message) or a channel.

This type is used for all kinds of @code{PRIVMSG} commands sent from the server, which includes CTCP
@code{ACTION}s. However, CTCP actions will be parsed, so @racket[content] will not include the extra
CTCP formatting. Since it it useful to distinguish between the two types of messages, the
@racket[IrcMessage-ChatMessage] and @racket[IrcMessage-ActionMessage] subtypes are provided.

Note that @racket[IrcMessage-Notice] is @italic{not} a subtype of @racket[IrcMessage-Message]—it is an
independent structure type.}

@deftogether[(@defstruct*[(IrcMessage-ChatMessage IrcMessage-Message) () #:transparent]
              @defstruct*[(IrcMessage-ActionMessage IrcMessage-Message) () #:transparent])]{
Subtypes of @racket[IrcMessage-Message] used to distinguish between normal chat messages and CTCP
@code{ACTION}s. See @racket[IrcMessage-Message] for more information.}

@defstruct*[(IrcMessage-Notice IrcMessage) ([sender IrcUser] [recipient String] [content String])
             #:transparent]{
Similar to @racket[IrcMessage-Message] but for @code{NOTICE} commands rather than @code{PRIVMSG}
commands.}

@defstruct*[(IrcMessage-Join IrcMessage) ([user IrcUser] [channel String]) #:transparent]{
Sent when a @racket[user] joins a @racket[channel] the client is currently connected to.}

@defstruct*[(IrcMessage-Part IrcMessage) ([user IrcUser] [channel String] [reason String])
            #:transparent]{
Sent when a @racket[user] leaves a @racket[channel] the client is currently connected to. Also
includes the provided @racket[reason] for leaving the channel (though it may be empty).}

@defstruct*[(IrcMessage-Quit IrcMessage) ([user IrcUser] [reason String]) #:transparent]{
Sent when a @racket[user] disconnects from the server. Also includes the provided @racket[reason] for
leaving (though it may be empty).}

@defstruct*[(IrcMessage-Kick IrcMessage) ([user IrcUser] [channel String] [kicked-user String]
                                          [reason String])
            #:transparent]{
Sent when a the user with @racket[kicked-user] as a nickname is kicked from a @racket[channel] by
@racket[user]. Also includes the provided @racket[reason] the user was kicked (though it may be
empty).}

@defstruct*[(IrcMessage-Kill IrcMessage) ([user IrcUser] [killed-user String] [reason String])
            #:transparent]{
Sent when a the user with @racket[kicked-user] as a nickname is forcibly disconnected from the server
by @racket[user]. Also includes the provided @racket[reason] the user was killed.}

@defstruct*[(IrcMessage-Nick IrcMessage) ([user IrcUser] [new-nick String]) #:transparent]{
Sent when a @racket[user]'s nickname is changed to @racket[new-nick].}

@section{Falling Back to the Low-Level API}

The @racketmodname[irc-client] library does provide tools for interacting with the lower-level
@racketmodname[irc] API if necessary. The underlying @racket[irc:irc-connection?] instance is
accessible via the @racket[IrcConnection-internal-connection] field, and every instance of
@racket[IrcMessage] includes the @racket[IrcMessage-internal-message] field for retrieving the
@racket[irc:irc-message] instance.

