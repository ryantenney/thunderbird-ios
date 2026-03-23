// Typealiases to disambiguate Account module types from JMAP/IMAP types
// that share the same names (Server, Authorization).
//
// Swift cannot use a module as a qualifier when a type in that module
// has the same name as the module itself (Account.Account).

import Account

typealias AccountServer = Server
typealias AccountAuthorization = Authorization
