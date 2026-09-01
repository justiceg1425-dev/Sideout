import XCTest
@testable import SideoutEngine

final class GameTests: XCTestCase {

    // MARK: - Side-out doubles

    func testDoublesSideOutOpensAtZeroZeroTwo() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .doubles, firstServer: .a))
        let s = game.state
        XCTAssertEqual(s.points, [0, 0])
        XCTAssertEqual(s.servingTeam, .a)
        XCTAssertEqual(s.serverNumber, 2)
        XCTAssertEqual(s.serverCourtSide, .right)
        XCTAssertEqual(game.spokenCallout(), [.openingZeroZeroTwo])
    }

    func testServingSideWinningScoresAPoint() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .doubles, firstServer: .a))
        let outcome = game.recordRally(wonBy: .a)
        XCTAssertEqual(outcome, .pointScored(by: .a))
        let s = game.state
        XCTAssertEqual(s.points, [1, 0])
        XCTAssertEqual(s.servingTeam, .a)
        XCTAssertEqual(s.serverNumber, 2)
        XCTAssertFalse(s.lastRallyWasSideOut)
    }

    func testOpeningServerLosingIsImmediateSideOut() {
        // At 0-0-2, the first side only has one server: receiver winning
        // sides out immediately, per the brief's opening-server rule.
        let game = Game(settings: GameSettings(format: .sideOut, players: .doubles, firstServer: .a))
        let outcome = game.recordRally(wonBy: .b)
        XCTAssertEqual(outcome, .sideOut(to: .b))
        let s = game.state
        XCTAssertEqual(s.points, [0, 0])
        XCTAssertEqual(s.servingTeam, .b)
        XCTAssertEqual(s.serverNumber, 1)
        XCTAssertTrue(s.lastRallyWasSideOut)
    }

    func testServerOneLosingAdvancesToServerTwoWithoutSideOut() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .doubles, firstServer: .a))
        game.recordRally(wonBy: .a) // 1-0, still server 2 (opening quirk)
        game.recordRally(wonBy: .a) // 2-0, still server 2
        game.recordRally(wonBy: .b) // side out -> b serves, server 1
        XCTAssertEqual(game.state.servingTeam, .b)
        XCTAssertEqual(game.state.serverNumber, 1)

        let outcome = game.recordRally(wonBy: .a) // b's server 1 loses -> advances to server 2
        XCTAssertEqual(outcome, .serverAdvanced)
        let s = game.state
        XCTAssertEqual(s.points, [2, 0]) // unchanged
        XCTAssertEqual(s.servingTeam, .b) // same side keeps serving
        XCTAssertEqual(s.serverNumber, 2)
        XCTAssertFalse(s.lastRallyWasSideOut)
    }

    func testServerTwoLosingIsSideOut() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .doubles, firstServer: .a))
        game.recordRally(wonBy: .b) // opening side-out -> b serves, server 1
        game.recordRally(wonBy: .a) // b's server 1 loses -> server 2
        XCTAssertEqual(game.state.serverNumber, 2)

        let outcome = game.recordRally(wonBy: .a) // b's server 2 loses -> full side out
        XCTAssertEqual(outcome, .sideOut(to: .a))
        let s = game.state
        XCTAssertEqual(s.servingTeam, .a)
        XCTAssertEqual(s.serverNumber, 1)
        XCTAssertTrue(s.lastRallyWasSideOut)
    }

    // MARK: - Court side

    func testCourtSideTracksServingTeamParity() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .singles, firstServer: .a))
        XCTAssertEqual(game.state.serverCourtSide, .right) // 0 is even
        game.recordRally(wonBy: .a)
        XCTAssertEqual(game.state.serverCourtSide, .left) // 1 is odd
        game.recordRally(wonBy: .a)
        XCTAssertEqual(game.state.serverCourtSide, .right) // 2 is even
    }

    // MARK: - Singles

    func testSinglesHasNoSecondServer() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .singles, firstServer: .a))
        XCTAssertEqual(game.state.serverNumber, 1)
        let outcome = game.recordRally(wonBy: .b)
        XCTAssertEqual(outcome, .sideOut(to: .b))
        XCTAssertEqual(game.state.serverNumber, 1)
    }

    // MARK: - Rally scoring

    func testRallyFormatAlwaysScores() {
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, firstServer: .a))
        XCTAssertEqual(game.state.serverNumber, 1)
        let outcome1 = game.recordRally(wonBy: .b)
        XCTAssertEqual(outcome1, .pointScored(by: .b))
        XCTAssertEqual(game.state.points, [0, 1])
        XCTAssertEqual(game.state.servingTeam, .b)

        let outcome2 = game.recordRally(wonBy: .b)
        XCTAssertEqual(outcome2, .pointScored(by: .b))
        XCTAssertEqual(game.state.points, [0, 2])
        XCTAssertFalse(game.state.lastRallyWasSideOut)
    }

    // MARK: - Win conditions

    func testWinByTwoRequiresMargin() {
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, pointsToWin: 11, winBy: 2, firstServer: .a))
        for _ in 0..<10 { game.recordRally(wonBy: .a) }
        for _ in 0..<10 { game.recordRally(wonBy: .b) }
        XCTAssertEqual(game.state.points, [10, 10])
        XCTAssertNil(game.state.winner)

        game.recordRally(wonBy: .a) // 11-10
        XCTAssertNil(game.state.winner)

        game.recordRally(wonBy: .a) // 12-10
        XCTAssertEqual(game.state.winner, .a)
    }

    func testHardCapWinsOutrightWithoutMargin() {
        // Alternating winners keeps the margin at 0 or 1 the whole way, so
        // this can reach 14-14 without an ordinary win-by-2 firing first —
        // unlike one side running the score up unopposed, which would hit
        // the normal win condition (e.g. 12-10) long before ever nearing
        // the cap.
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, pointsToWin: 11, winBy: 2, hardCap: 15, firstServer: .a))
        for _ in 0..<14 {
            game.recordRally(wonBy: .a)
            game.recordRally(wonBy: .b)
        }
        XCTAssertEqual(game.state.points, [14, 14])
        XCTAssertNil(game.state.winner)

        game.recordRally(wonBy: .b) // 14-15 — only a 1-point margin, but hits the cap outright
        XCTAssertEqual(game.state.winner, .b)
    }

    func testRecordRallyNoOpsAfterGameEnds() {
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, pointsToWin: 11, firstServer: .a))
        for _ in 0..<11 { game.recordRally(wonBy: .a) }
        XCTAssertEqual(game.state.winner, .a)
        let count = game.rallyCount
        let outcome = game.recordRally(wonBy: .b)
        XCTAssertNil(outcome)
        XCTAssertEqual(game.rallyCount, count)
    }

    // MARK: - Undo and scrubbing

    func testUndoRemovesLastRally() {
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, firstServer: .a))
        game.recordRally(wonBy: .a)
        game.recordRally(wonBy: .b)
        XCTAssertEqual(game.state.points, [1, 1])
        game.undo()
        XCTAssertEqual(game.state.points, [1, 0])
        XCTAssertEqual(game.rallyCount, 1)
    }

    func testUndoOnEmptyHistoryIsANoOp() {
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, firstServer: .a))
        game.undo()
        XCTAssertEqual(game.rallyCount, 0)
    }

    func testScrubbingReplaysAnyPrefix() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .doubles, firstServer: .a))
        game.recordRally(wonBy: .a) // 1-0
        game.recordRally(wonBy: .a) // 2-0
        game.recordRally(wonBy: .b) // side out, b serves
        game.recordRally(wonBy: .b) // 2-1

        XCTAssertEqual(game.state(atRallyCount: 0).points, [0, 0])
        XCTAssertEqual(game.state(atRallyCount: 2).points, [2, 0])
        XCTAssertEqual(game.state(atRallyCount: 2).servingTeam, .a)
        XCTAssertEqual(game.state(atRallyCount: 3).servingTeam, .b)
        XCTAssertEqual(game.state(atRallyCount: 4).points, [2, 1])
        // Live state is unaffected by having scrubbed.
        XCTAssertEqual(game.state.points, [2, 1])
    }

    // MARK: - Point signals

    func testGamePointOnlyForServingSideUnderSideOut() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .singles, pointsToWin: 11, winBy: 2, firstServer: .a))
        for _ in 0..<10 { game.recordRally(wonBy: .a) }
        XCTAssertEqual(game.state.points, [10, 0])
        XCTAssertEqual(game.pointSignal(for: .a), .gamePoint(for: .a))
        XCTAssertNil(game.pointSignal(for: .b))
    }

    func testMatchPointAtHardCapBoundary() {
        // Same issue as the hard-cap test above: 14 straight wins for one
        // side ends the game at 11-0 long before reaching 14. Alternate to
        // 13-13, then one more so `.a` leads 14-13 (still only a 1-point
        // margin, so the game isn't over) with `.a` one point from the cap.
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, pointsToWin: 11, winBy: 2, hardCap: 15, firstServer: .a))
        for _ in 0..<13 {
            game.recordRally(wonBy: .a)
            game.recordRally(wonBy: .b)
        }
        game.recordRally(wonBy: .a)
        XCTAssertEqual(game.state.points, [14, 13])
        XCTAssertNil(game.state.winner)
        XCTAssertEqual(game.pointSignal(for: .a), .matchPoint(for: .a))
    }

    // MARK: - Spoken callouts

    func testSpokenCalloutDoublesSideOutIncludesServerNumber() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .doubles, firstServer: .a))
        game.recordRally(wonBy: .b) // side out -> b serves, server 1; score still 0-0
        XCTAssertEqual(game.spokenCallout(), [.sideOut, .number(0), .number(0), .number(1)])
    }

    func testSpokenCalloutSinglesHasNoServerNumber() {
        let game = Game(settings: GameSettings(format: .sideOut, players: .singles, firstServer: .a))
        game.recordRally(wonBy: .a)
        XCTAssertEqual(game.spokenCallout(), [.number(1), .number(0)])
    }

    func testSpokenCalloutRallyHasNoServerNumberOrSideOutPrefix() {
        // The assembly rule is "serving score, then receiving score" — not
        // a fixed team order. `.b` won the rally and now serves under
        // rally scoring, so `.b`'s score (1) is announced first even
        // though `.a` is team "us".
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, firstServer: .a))
        game.recordRally(wonBy: .b)
        XCTAssertEqual(game.spokenCallout(), [.number(1), .number(0)])
    }

    func testSpokenCalloutOnGameEnd() {
        let game = Game(settings: GameSettings(format: .rally, players: .doubles, pointsToWin: 11, firstServer: .a))
        for _ in 0..<11 { game.recordRally(wonBy: .a) }
        XCTAssertEqual(game.spokenCallout(), [.game, .us, .number(11), .number(0)])
    }

    func testClassifyIsUsableStandaloneForAReplica() {
        let before = GameState(points: [4, 3], servingTeam: .a, serverNumber: 1, serverCourtSide: .right, lastRallyWasSideOut: false, winner: nil, ralliesPlayed: 5)
        let after = GameState(points: [4, 3], servingTeam: .b, serverNumber: 1, serverCourtSide: .right, lastRallyWasSideOut: true, winner: nil, ralliesPlayed: 6)
        let settings = GameSettings(format: .sideOut, players: .singles)
        XCTAssertEqual(Game.classify(before: before, after: after, wonBy: .b, settings: settings), .sideOut(to: .b))
    }
}
