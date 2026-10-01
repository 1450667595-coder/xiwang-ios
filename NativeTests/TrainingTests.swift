import XCTest
@testable import XiWang

final class TrainingTests:XCTestCase {
    func testSkipIncludesBothSidesWithoutLosingCompletedSets() {
        var t = Training(steps:Step.make(Choice.defaults)); t.steps[0].completed = 1; t.skip()
        XCTAssertTrue(t.steps[0].skipped); XCTAssertTrue(t.steps[1].skipped); XCTAssertEqual(t.steps[0].completed,1); XCTAssertEqual(t.steps[t.index].id,"wall")
    }
    func testSetCountNeverExceedsPlan() { var t = Training(steps:[Step(key:"a",id:"ankle",side:"",sets:1,reps:20,hold:5,completed:0,skipped:false)]); t.completeSet(); t.completeSet(); XCTAssertEqual(t.steps[0].completed,1); XCTAssertNil(t.started) }
    func testPauseStopsElapsedTimeAndHoldTimer() { var t = Training(steps:Step.make(Choice.defaults)); t.started = Date().addingTimeInterval(-10); t.deadline = Date().addingTimeInterval(5); t.pause(); XCTAssertEqual(t.seconds,10); XCTAssertNil(t.started); XCTAssertNil(t.deadline) }
    func testDisabledProjectsNeverEnterSession() { var choices = Choice.defaults; choices[0].enabled = false; XCTAssertFalse(Step.make(choices).contains{$0.id == "straight"}) }
    func testHoldingTimerSurvivesPauseAndResume() { var t = Training(steps:Step.make(Choice.defaults)); t.resume(); t.deadline = Date().addingTimeInterval(20); t.pause(); XCTAssertEqual(t.holdRemaining ?? 0,20,accuracy:1); t.resume(); XCTAssertEqual(t.deadline?.timeIntervalSinceNow ?? 0,20,accuracy:1) }
    func testNullableCareMinutesRoundTripAndDeletion() throws { var care = Care(id:UUID().uuidString,date:"2026-10-02",kind:"patch",time:"08:00",minutes:nil,notes:"",revision:1,deleted:false); care.deleted = true; let data = try JSONEncoder().encode(care); let json = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]); XCTAssertTrue(json["minutes"] is NSNull); let decoded = try JSONDecoder().decode(Care.self,from:data); XCTAssertNil(decoded.minutes); XCTAssertTrue(decoded.deleted) }
    func testNullablePhotoIDIsPresentInAPIJSON() throws { let ap = Appearance(prefs:Preferences(),revision:0); let data = try JSONEncoder().encode(ap); let json = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]); XCTAssertTrue(json["photoId"] is NSNull) }
    func testSessionPayloadRoundTripKeepsStableID() throws { let t = Training(steps:Step.make(Choice.defaults)); let p = SessionPayload(id:t.id,date:t.date,seconds:5,steps:t.steps,planNote:"",pain:nil,swelling:false,feeling:"",notes:""); let d = try JSONEncoder().encode(p); XCTAssertEqual(try JSONDecoder().decode(SessionPayload.self,from:d).id,t.id); let json = try XCTUnwrap(JSONSerialization.jsonObject(with:d) as? [String:Any]); XCTAssertNil(json["started"]); XCTAssertEqual(json["type"] as? String,"session") }
}
