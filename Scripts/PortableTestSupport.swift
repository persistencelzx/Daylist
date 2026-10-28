// Runs the exact same assertions as XCTest on Macs with only Command Line Tools.
// This is not an iOS integration test substitute.
import Foundation

class XCTestCase {}
enum TestResults {
    static var failures = 0
    static func fail(_ message: String, file: StaticString, line: UInt) {
        failures += 1
        print("FAIL \(file):\(line): \(message)")
    }
}
func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    do { if try !value() { TestResults.fail("Expected true", file: file, line: line) } }
    catch { TestResults.fail("Unexpected error: \(error)", file: file, line: line) }
}
func XCTAssertFalse(_ value: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    do { if try value() { TestResults.fail("Expected false", file: file, line: line) } }
    catch { TestResults.fail("Unexpected error: \(error)", file: file, line: line) }
}
func XCTAssertEqual<T: Equatable>(_ actual: @autoclosure () throws -> T, _ expected: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try actual(), b = try expected()
        if a != b { TestResults.fail("\(a) != \(b)", file: file, line: line) }
    } catch { TestResults.fail("Unexpected error: \(error)", file: file, line: line) }
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try expression(); TestResults.fail("Expected an error", file: file, line: line) }
    catch {}
}
