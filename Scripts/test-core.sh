#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${DAYLIST_TEST_BUILD_DIR:-$ROOT/.build/portable-tests}"
mkdir -p "$BUILD_DIR"
python3 - "$ROOT" "$BUILD_DIR" <<'PY'
from pathlib import Path
import re, sys
root, build = map(Path, sys.argv[1:])
source = (root/'Tests/DaylistCoreTests.swift').read_text()
names = re.findall(r'func (test\w+)\(\)( throws)?', source)
calls = []
for name, throws in names:
    call = ('try ' if throws else '') + f'suite.{name}()'
    if throws:
        call = f'do {{ {call} }} catch {{ TestResults.fail("Unexpected error: \\(error)", file: #filePath, line: #line) }}'
    calls.append(f'''do {{
        let before = TestResults.failures
        {call}
        print("\\(TestResults.failures == before ? "PASS" : "FAIL") {name}")
    }}''')
runner = 'import Foundation\n@main struct Runner { static func main() {\n let suite = DaylistCoreTests()\n'
runner += '\n'.join(calls)
runner += f'\n print("{len(names)} cases; \\(TestResults.failures) failed assertions")\n exit(TestResults.failures == 0 ? 0 : 1)\n}}}}\n'
(build/'Runner.swift').write_text(runner)
PY
swiftc -D PORTABLE_TESTS \
  "$ROOT/Shared/Core.swift" "$ROOT/Shared/Store.swift" "$ROOT/Shared/ReminderPlan.swift" \
  "$ROOT/Scripts/PortableTestSupport.swift" "$ROOT/Tests/DaylistCoreTests.swift" \
  "$BUILD_DIR/Runner.swift" -o "$BUILD_DIR/core-tests"
"$BUILD_DIR/core-tests"
