//
//  RestoreCursorAutowrapTests.swift
//
//  Restoring the cursor (DECRC, SCORC, leaving the alternate screen with
//  ?1049l, ?1048l) must not change autowrap (DECAWM), as in xterm and Ghostty.
//  It used to restore a saved autowrap flag that defaulted to false, so a
//  ?1049l with no earlier save (herdr-core sends one at the start of every
//  attach) turned autowrap off and every soft-wrapped line nvim drew landed
//  on the last column instead of the next row.
//

import Foundation
import Testing

@testable import SwiftTerm

final class RestoreCursorAutowrapTests: TerminalDelegate {
    func send(source: Terminal, data: ArraySlice<UInt8>) {}

    private func makeTerminal() -> Terminal {
        Terminal(delegate: self, options: TerminalOptions(cols: 10, rows: 3))
    }

    private func row(_ terminal: Terminal, _ y: Int) -> String {
        terminal.getLine(row: y)?.translateToString(trimRight: true) ?? ""
    }

    /// Fills the first row, then prints two more characters, which only reach
    /// the second row if autowrap is on.
    private func expectLongLineWraps(_ terminal: Terminal) {
        terminal.feed(text: "\u{1b}[H" + String(repeating: "A", count: 10) + "\u{1b}(B\u{1b}[mXY")
        #expect(row(terminal, 0) == String(repeating: "A", count: 10))
        #expect(row(terminal, 1) == "XY")
    }

    @Test(arguments: [
        "\u{1b}[?1049l",  // leave the alternate screen without entering it
        "\u{1b}[?1048l",  // restore cursor (xterm private mode)
        "\u{1b}8",        // DECRC
        "\u{1b}[u",       // SCORC
    ])
    func restoreWithoutSaveKeepsAutowrap(sequence: String) {
        let terminal = makeTerminal()
        terminal.feed(text: sequence)
        #expect(terminal.wraparound)
        expectLongLineWraps(terminal)
    }

    @Test func herdrCoreFirstPaintPrefixKeepsAutowrap() {
        // The mode resets herdr-core sends before repainting the screen.
        let firstPaintPrefix = "\u{18}\u{1b}[!p\u{1b}[?2026l\u{1b}[?9l\u{1b}[?1000l\u{1b}[?1001l"
            + "\u{1b}[?1002l\u{1b}[?1003l\u{1b}[?1004l\u{1b}[?1005l\u{1b}[?1006l\u{1b}[?1015l"
            + "\u{1b}[?1016l\u{1b}[?2004l\u{1b}[?1l\u{1b}[?66l\u{1b}[?2031l\u{1b}[?2048l"
            + "\u{1b}[=0;1u\u{1b}[?1049l\u{1b}[?1047l\u{1b}[?47l\u{1b}[H\u{1b}[2J\u{1b}[0m"
            + "\u{1b}[?1004h\u{1b}[?1049h"
        let terminal = makeTerminal()
        terminal.feed(text: firstPaintPrefix)
        #expect(terminal.wraparound)
        expectLongLineWraps(terminal)
    }

    @Test func restoreDoesNotBringBackAutowrapTheProgramTurnedOff() {
        let terminal = makeTerminal()
        terminal.feed(text: "\u{1b}7\u{1b}[?7l\u{1b}8")
        #expect(!terminal.wraparound)
    }
}
