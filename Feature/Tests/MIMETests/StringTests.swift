import Foundation
@testable import MIME
import Testing

struct StringTests {
    @Test func crlf() {
        #expect(String.crlf == "\r\n")
    }

    @Test func separator() {
        #expect(String.separator == "-")
    }

    @Test func ascii() {
        #expect("👎 NOT ASCII".ascii == nil)
        #expect("/@scii=12345...".ascii == "/@scii=12345...")
        #expect("".ascii == "")
    }

    @Test func capitalized() {
        #expect("when i was little".capitalized(.sentence) == "When i was little")
        #expect("when I was little".capitalized(.sentence) == "When I was little")
        #expect("when i was little".capitalized(.title) == "When I Was Little")
        #expect("when i was little".capitalized == "When I Was Little")
    }

    @Test func parameters() {
        #expect(
            "multipart/alternative; boundary=\"_----------=_17617196041979919223967\"".parameters == [
                "boundary": "_----------=_17617196041979919223967"
            ])
        #expect(
            "multipart/mixed;\nboundary=\"----=_Part_15950895_843396275.1764942606546\"".parameters == [
                "boundary": "----=_Part_15950895_843396275.1764942606546"
            ])
        #expect(
            "multipart/alternative;\nboundary=\"b1_dd99cd789bcc10ebb82bcc39304a9664\"".parameters == [
                "boundary": "b1_dd99cd789bcc10ebb82bcc39304a9664"
            ])
        #expect(
            "text/plain; charset=utf-8; charset=\"utf-8\"".parameters == [
                "charset": "utf-8"
            ])
        #expect(
            "text/html; charset=ISO-8859-1".parameters == [
                "charset": "ISO-8859-1"
            ])
        #expect(
            "inline; filename=mime-part.jpg; modification-date=\"Mon, 31 Oct 1977 08:14:00 +0000 (GMT)\"".parameters == [
                "filename": "mime-part.jpg",
                "modification-date": "Mon, 31 Oct 1977 08:14:00 +0000 (GMT)"
            ])
        #expect(
            "attachment; filename=\"mime-part.zip\"; creation-date=\"Mon, 31 Oct 1977 08:14:00 +0000 (GMT)\"; modification-date=\"Mon, 31 Oct 1977 03:14:00-0500\"".parameters == [
                "filename": "mime-part.zip",
                "creation-date": "Mon, 31 Oct 1977 08:14:00 +0000 (GMT)",
                "modification-date": "Mon, 31 Oct 1977 03:14:00-0500"
            ])
        #expect(
            "attachment; filename=\"mime-part.png\"".parameters == [
                "filename": "mime-part.png"
            ])
        #expect("inline".parameters == [:])
    }

    @Test func headerDecoded() throws {
        #expect(try "=?utf-8?B?4p2k77iP4p2k77iP4p2k77iPw6nDhvCfpJYiXOKdpO+4j+KdpO+4jw==?=".headerDecoded() == "❤️❤️❤️éÆ🤖\"\\❤️❤️")
        #expect(try "=?utf-8?Q?=E2=9D=A4=EF=B8=8F=E2=9D=A4=EF=B8=8F=E2=9D=A4=EF=B8=8F=C3=A9=C3=86=F0=9F=A4=96\"\\=E2=9D=A4=EF=B8=8F=E2=9D=A4=EF=B8=8F?=".headerDecoded() == "❤️❤️❤️éÆ🤖\"\\❤️❤️")
        #expect(try encodedQuotedPrintable.headerDecoded() == "❤️❤️❤️éÆ🤖\"\\❤️❤️")
        #expect(throws: MIMEError.self) {
            try "=?utf-8?B?4p2k77iP4p2k77iP4p2k77iPw6nDhvCfpJYi+4j+KdpO+4jw==?=".headerDecoded()
        }
    }

    @Test func headerEncoded() throws {
        #expect(try "❤️❤️❤️éÆ🤖\"\\❤️❤️".headerEncoded() == "=?UTF-8?B?4p2k77iP4p2k77iP4p2k77iPw6nDhvCfpJYiXOKdpO+4j+KdpO+4jw==?=")
        #expect(try "Plain ASCII string requiring 0/no encoding".headerEncoded() == "Plain ASCII string requiring 0/no encoding")
        #expect(try "".headerEncoded() == "")
    }

    @Test func quotedPrintableInit() throws {
        #expect(try String(quotedPrintable: .quotedPrintable) == decodedQuotedPrintable)
        #expect(throws: MIMEError.self) {
            try String(quotedPrintable: .quotedPrintable, encoding: .ascii)
        }
    }

    @Test func decodingQuotedPrintable() throws {
        let quotedPrintable: String = String(data: .quotedPrintable, encoding: .ascii)!
            .replacingOccurrences(of: "=\r\n", with: "")
            .replacingOccurrences(of: "=\n", with: "")
        #expect(try quotedPrintable.decodingQuotedPrintable() == decodedQuotedPrintable)
        #expect(throws: MIMEError.self) {
            try quotedPrintable.decodingQuotedPrintable(to: .ascii)
        }
    }

    @Test func decodingBase64() throws {
        #expect(try "4p2k77iP4p2k77iP4p2k77iPw6nDhvCfpJYiXOKdpO+4j+KdpO+4jw==".decodingBase64() == "❤️❤️❤️éÆ🤖\"\\❤️❤️")
        #expect(throws: MIMEError.self) {
            try "4p2k77iP4p2k77iPw6nDhvCfpJYi4j+KdpO+4jw==".decodingBase64()
        }
    }
}

private extension Data {
    static var quotedPrintable: Self { try! Bundle.module.data(forResource: "mime-part.html") }
}

// swift-format-ignore
private let decodedQuotedPrintable: String = """
<!DOCTYPE html>
<style>

    :root {
        color-scheme: light dark;
    }

</style>
<p>HTML MIME part with local <a href="#anchor">⚓️ link</a>, <a href="https://www.thunderbird.net/donate/mobile/?form=tfi">remote link</a> and remote image</p>
<p><img id="anchor" src="https://avatars.githubusercontent.com/u/15187237" alt="Thunderbird avatar"></p>

"""

// swift-format-ignore
private let encodedQuotedPrintable: String = """
=?utf-8?Q?=E2=9D=A4=EF=B8=8F=E2=9D=A4=EF=B8=8F=E2=9D=A4=EF=B8=8F=C3=A9=C3=86=
=F0=9F=A4=96"\\=E2=9D=A4=EF=B8=8F=E2=9D=A4=EF=B8=8F?=
"""
