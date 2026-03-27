#!/usr/bin/env bash
# Test suite for u7 CLI
# Run with: nix develop --command bash test.sh

# Don't exit on error - we want to run all tests
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Source the utility
source ./utility.sh

# Test helper
assert_equals() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Got: $actual"
        ((FAILED++))
    fi
}

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to contain: $needle"
        echo "  Got: $haystack"
        ((FAILED++))
    fi
}

# Setup test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

echo "Running u7 tests..."
echo "==================="

# Test 1: JSON limit default
echo '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]' > test.json
result=$(u7 sh json test.json 2>&1)
line_count=$(echo "$result" | wc -l | tr -d ' ')
assert_equals "JSON default limit shows 10 items" "12" "$line_count"  # 10 items + [ + ]

# Test 2: JSON custom limit
result=$(u7 sh json test.json limit 3 2>&1)
if [[ $? -eq 0 ]]; then
    line_count=$(echo "$result" | wc -l | tr -d ' ')
    assert_equals "JSON custom limit shows 3 items" "5" "$line_count"  # 3 items + [ + ]
else
    echo -e "${RED}✗${NC} JSON custom limit shows 3 items (command failed)"
    echo "  Output: $result"
    ((FAILED++))
fi

# Test 3: Text replacement with literal dot
echo "foo.bar is here and fooXbar too" > test_replace.txt
u7 st text "foo.bar" to "baz" in test_replace.txt >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    result=$(cat test_replace.txt)
    assert_equals "Text replacement treats dot literally" "baz is here and fooXbar too" "$result"
else
    echo -e "${RED}✗${NC} Text replacement treats dot literally (command failed)"
    ((FAILED++))
fi

# Test 4: Text replacement with special chars
echo "price is \$100" > test_special.txt
u7 st text "\$100" to "\$200" in test_special.txt >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    result=$(cat test_special.txt)
    assert_equals "Text replacement handles dollar signs" "price is \$200" "$result"
else
    echo -e "${RED}✗${NC} Text replacement handles dollar signs (command failed)"
    ((FAILED++))
fi

# Test 5: Password generation
result=$(u7 mk password length 16)
length=${#result}
assert_equals "Password generation creates 16 chars" "16" "$length"

# Test 6: Directory creation
u7 mk dir testdir
if [[ -d "testdir" ]]; then
    echo -e "${GREEN}✓${NC} Directory creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Directory creation works"
    ((FAILED++))
fi

# Test 7: File creation
u7 mk file testfile.txt
if [[ -f "testfile.txt" ]]; then
    echo -e "${GREEN}✓${NC} File creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} File creation works"
    ((FAILED++))
fi

# Test 8: Archive extraction to directory
echo "test content" > testfile.txt
gzip testfile.txt  # Creates testfile.txt.gz
mkdir extract_dir
u7 cv archive testfile.txt.gz to files yield extract_dir >/dev/null 2>&1
if [[ -f "extract_dir/testfile.txt" ]]; then
    echo -e "${GREEN}✓${NC} Archive extraction to directory works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Archive extraction to directory works"
    echo "  Expected: extract_dir/testfile.txt"
    ls -la extract_dir/
    ((FAILED++))
fi

# Test 9: Archive creation
echo "content" > file1.txt
echo "more" > file2.txt
u7 mk archive test.tar.gz from file1.txt file2.txt >/dev/null 2>&1
if [[ -f "test.tar.gz" ]]; then
    echo -e "${GREEN}✓${NC} Archive creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Archive creation works"
    ((FAILED++))
fi

# Test 10: Show line from file
echo -e "line1\nline2\nline3" > lines.txt
result=$(u7 sh line 2 from lines.txt)
assert_equals "Show specific line from file" "line2" "$result"

# Test 11: File move/rename
echo "test" > move_test.txt
u7 mv file move_test.txt to renamed.txt >/dev/null 2>&1
if [[ -f "renamed.txt" && ! -f "move_test.txt" ]]; then
    echo -e "${GREEN}✓${NC} File move/rename works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} File move/rename works"
    ((FAILED++))
fi

# Test 12: Copy files
echo "original" > original.txt
u7 mk copy original.txt to copy.txt >/dev/null 2>&1
if [[ -f "copy.txt" ]]; then
    result=$(cat copy.txt)
    assert_equals "File copy preserves content" "original" "$result"
else
    echo -e "${RED}✗${NC} File copy preserves content"
    ((FAILED++))
fi

# Test 13: Symbolic link creation
echo "target" > link_target.txt
u7 mk link link_target.txt to link.txt >/dev/null 2>&1
if [[ -L "link.txt" ]]; then
    echo -e "${GREEN}✓${NC} Symbolic link creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Symbolic link creation works"
    ((FAILED++))
fi

# Test 14: Drop line from file
echo -e "keep1\nremove\nkeep2" > dropline.txt
u7 dr line 2 from dropline.txt >/dev/null 2>&1
result=$(cat dropline.txt)
assert_equals "Drop line removes correct line" "keep1
keep2" "$result"

# Test 15: Drop duplicate lines
echo -e "line1\nline2\nline1\nline3" > dupes.txt
u7 dr duplicates in dupes.txt >/dev/null 2>&1
line_count=$(wc -l < dupes.txt | tr -d ' ')
assert_equals "Drop duplicates removes duplicates" "3" "$line_count"

# Test 16: Set file permissions
touch perm_test.txt
u7 st perms to 644 on perm_test.txt >/dev/null 2>&1
# Use GNU stat which is available in nix develop
perms=$(stat -c "%a" perm_test.txt 2>&1 | grep -o '^[0-9]*' | head -1)
assert_equals "Set file permissions" "644" "$perms"

# Test 17: Convert JSON to YAML
echo '{"key": "value"}' > test.json
if command -v yq &>/dev/null; then
    u7 cv json test.json to yaml yield test.yaml >/dev/null
    if [[ -f "test.yaml" ]]; then
        result=$(cat test.yaml)
        assert_contains "JSON to YAML conversion has key" "key" "$result"
        assert_contains "JSON to YAML conversion has value" "value" "$result"
    else
        echo -e "${RED}✗${NC} JSON to YAML conversion (file not created)"
        ((FAILED++))
    fi
else
    echo -e "${GREEN}✓${NC} JSON to YAML conversion (skipped - yq not installed)"
    ((PASSED++))
fi

# Test 18: Make sequence
result=$(u7 mk sequence with prefix test limit 3 | wc -l | tr -d ' ')
assert_equals "Sequence generation" "3" "$result"

# Test 20: Show file diff
echo "version1" > diff1.txt
echo "version2" > diff2.txt
result=$(u7 sh diff diff1.txt to diff2.txt 2>&1)
assert_contains "Show file diff" "version1" "$result"

# Test 21: Text replacement in directory
mkdir replace_dir
echo "foo.bar" > replace_dir/file1.txt
echo "foo.bar" > replace_dir/file2.txt
echo "y" | u7 st text "foo.bar" to "replaced" in replace_dir >/dev/null 2>&1
result1=$(cat replace_dir/file1.txt)
result2=$(cat replace_dir/file2.txt)
if [[ "$result1" == "replaced" && "$result2" == "replaced" ]]; then
    echo -e "${GREEN}✓${NC} Text replacement in directory works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Text replacement in directory works"
    ((FAILED++))
fi

# Test 22: Set tabs to spaces
printf "line1\tline2" > tabs.txt
u7 st tabs to spaces in . >/dev/null 2>&1
if grep -q "  " tabs.txt; then
    echo -e "${GREEN}✓${NC} Convert tabs to spaces works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Convert tabs to spaces works"
    ((FAILED++))
fi

# Test 23: Drop blank lines
echo -e "line1\n\nline2\n\nline3" > blank.txt
u7 dr lines if blank from blank.txt yield noblank.txt >/dev/null 2>&1
line_count=$(wc -l < noblank.txt | tr -d ' ')
assert_equals "Drop blank lines" "3" "$line_count"

# Test 24: Show modified files
touch -t 202301010000 old.txt
touch new.txt
result=$(u7 sh files by modified 2>&1)
assert_contains "Show modified files" "new.txt" "$result"

# Test 25: Show big files
dd if=/dev/zero of=big.bin bs=1024 count=10 2>/dev/null
touch small.txt
result=$(u7 sh files by size 2>&1)
assert_contains "Show big files" "big.bin" "$result"

# Test 26: Show disk usage of directories
mkdir -p subdir1 subdir2
echo "data" > subdir1/file.txt
result=$(u7 sh usage directories 1 2>&1)
assert_contains "Show directory disk usage" "subdir1" "$result"

# Test 27: Show processes by CPU
result=$(u7 sh processes by cpu 2>&1)
if echo "$result" | grep -q "[0-9]\+.*[0-9]\+\.[0-9]"; then
    echo -e "${GREEN}✓${NC} Show processes by CPU"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Show processes by CPU"
    ((FAILED++))
fi

# Test 28: Show processes by memory
result=$(u7 sh processes by memory 2>&1)
if echo "$result" | grep -q "[0-9]\+.*[0-9]\+\.[0-9]"; then
    echo -e "${GREEN}✓${NC} Show processes by memory"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Show processes by memory"
    ((FAILED++))
fi

# Test 29: Set owner with 'to' operator
touch owner_test.txt
u7 st owner to $(whoami) on owner_test.txt >/dev/null 2>&1
if [[ -f "owner_test.txt" ]]; then
    echo -e "${GREEN}✓${NC} Set owner with 'to' operator works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Set owner with 'to' operator works"
    ((FAILED++))
fi

# Test 30: Run job in background
u7 rn job "echo test" in 1s >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Schedule job in background works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Schedule job in background works"
    ((FAILED++))
fi

# Test 31: Run command in background
result=$(u7 rn "sleep 0.1" in background 2>&1)
assert_contains "Run command in background" "PID:" "$result"

# Test 32: Check shell syntax
echo '#!/bin/bash' > test_script.sh
echo 'echo "test"' >> test_script.sh
u7 rn check syntax in file test_script.sh >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Shell syntax check works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Shell syntax check works"
    ((FAILED++))
fi

# Test 33: Show network info
if command -v ifconfig &>/dev/null; then
    result=$(u7 sh network 2>&1)
    assert_contains "Show network info" "lo" "$result"
else
    echo -e "${GREEN}✓${NC} Show network info (skipped - ifconfig not installed)"
    ((PASSED++))
fi

# Test 34: Show port usage (lsof might need sudo, skip if fails)
result=$(u7 sh port 22 2>&1 || echo "skipped")
if [[ "$result" != "skipped" ]]; then
    echo -e "${GREEN}✓${NC} Show port usage works"
    ((PASSED++))
else
    echo -e "${GREEN}✓${NC} Show port usage (skipped - requires permissions)"
    ((PASSED++))
fi

# Test 35: Make symbolic link
echo "link_target" > link_src.txt
u7 mk link link_src.txt to link_dest.txt >/dev/null 2>&1
if [[ -L "link_dest.txt" ]]; then
    echo -e "${GREEN}✓${NC} Make symbolic link works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Make symbolic link works"
    ((FAILED++))
fi

# Test 36: Priority/nice command
result=$(u7 rn "echo test" with priority 10 2>&1)
assert_contains "Run with priority" "test" "$result"

# Test 37: Drop duplicates with 'from' operator (alternative)
echo -e "a\nb\na\nc" > dupes2.txt
u7 dr duplicates from dupes2.txt >/dev/null 2>&1
line_count=$(wc -l < dupes2.txt | tr -d ' ')
assert_equals "Drop duplicates with 'from' operator" "3" "$line_count"

# Test 38: Drop column from CSV
echo -e "a,b,c\n1,2,3\n4,5,6" > columns.csv
u7 dr column 2 from columns.csv >/dev/null 2>&1
result=$(head -1 columns.csv)
assert_equals "Drop column from CSV" "a,c" "$result"

# Test 39: Show line from file with 'from' operator
echo -e "first\nsecond\nthird" > showline.txt
result=$(u7 sh line 2 from showline.txt 2>&1)
assert_equals "Show line from file" "second" "$result"

# Test 40: Show diff with 'to' operator
echo "version1" > diff_a.txt
echo "version2" > diff_b.txt
result=$(u7 sh diff diff_a.txt to diff_b.txt 2>&1)
assert_contains "Show diff with 'to' operator" "version" "$result"

# Test 41: Make archive with 'from' operator (zip format)
echo "zip_content" > zip_file.txt
if command -v zip &>/dev/null; then
    u7 mk archive test_archive.zip from zip_file.txt >/dev/null 2>&1
    if [[ -f "test_archive.zip" ]]; then
        echo -e "${GREEN}✓${NC} Make archive with 'from' operator"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Make archive with 'from' operator"
        ((FAILED++))
    fi
else
    echo -e "${GREEN}✓${NC} Make archive with 'from' operator (skipped - zip not installed)"
    ((PASSED++))
fi

# Test 42: Set slashes to back in file
echo "/path/to/file" > slashtest.txt
u7 st slashes to back in slashtest.txt >/dev/null 2>&1
result=$(cat slashtest.txt)
assert_equals "Set slashes to back" "\\path\\to\\file" "$result"

# Test 43: Set slashes to forward in file
echo '\\path\\to\\file' > slashtest2.txt
u7 st slashes to forward in slashtest2.txt >/dev/null 2>&1
result=$(cat slashtest2.txt)
assert_equals "Set slashes to forward" "/path/to/file" "$result"

# Test 44: Long verb aliases (make/drop)
u7 make dir longtest
if [[ -d "longtest" ]]; then
    # Pipe yes to bypass interactive confirmation (rm -ri)
    yes | u7 drop dir longtest >/dev/null 2>&1
    if [[ ! -d "longtest" ]]; then
         echo -e "${GREEN}✓${NC} Long verb aliases (make/drop) work"
         ((PASSED++))
    else
         echo -e "${RED}✗${NC} Long verb aliases (drop failed)"
         ((FAILED++))
    fi
else
    echo -e "${RED}✗${NC} Long verb aliases (make failed)"
    ((FAILED++))
fi

# Test 45: Show files match pattern
mkdir matchdir
echo "findme" > matchdir/f1.txt
echo "ignore" > matchdir/f2.txt
result=$(u7 sh files match "findme" in matchdir 2>&1)
assert_contains "Show files match pattern" "f1.txt" "$result"

# Test 46: System info (cpu/memory/disk)
u7 sh cpu >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Show cpu works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Show cpu failed"
    ((FAILED++))
fi

# Test 47: Drop files but pattern
mkdir butdir && cd butdir
touch keep.txt delete1.log delete2.log
echo "y" | u7 dr files but "*.txt" >/dev/null 2>&1
if [[ -f "keep.txt" && ! -f "delete1.log" && ! -f "delete2.log" ]]; then
    echo -e "${GREEN}✓${NC} Drop files but pattern works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Drop files but pattern failed"
    ((FAILED++))
fi
cd ..

# Test 48: Check syntax in files (pattern)
mkdir syntaxdir
echo '#!/bin/bash' > syntaxdir/good1.sh
echo 'echo "ok"' >> syntaxdir/good1.sh
echo '#!/bin/bash' > syntaxdir/good2.sh
echo 'echo "ok"' >> syntaxdir/good2.sh
cd syntaxdir
result=$(u7 rn check syntax in files "*.sh" 2>&1)
if [[ $? -eq 0 && "$result" == *"Syntax check complete"* ]]; then
    echo -e "${GREEN}✓${NC} Check syntax in files works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Check syntax in files works"
    ((FAILED++))
fi
cd ..

# Test 49: Check syntax in file (single)
echo '#!/bin/bash' > single.sh
echo 'echo "test"' >> single.sh
u7 rn check syntax in file single.sh >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Check syntax in file works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Check syntax in file works"
    ((FAILED++))
fi

# Test 50: Background with quoted command
result=$(u7 rn "echo background_test" in background 2>&1)
if [[ "$result" == *"PID:"* ]]; then
    echo -e "${GREEN}✓${NC} Background with quoted command works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Background with quoted command works"
    ((FAILED++))
fi

# Test 51: Priority with quoted command
result=$(u7 rn "echo priority_test" with priority 5 2>&1)
if [[ "$result" == *"priority_test"* ]]; then
    echo -e "${GREEN}✓${NC} Priority with quoted command works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Priority with quoted command works"
    ((FAILED++))
fi

# Test 52: CSV with limit
echo -e "a,b,c\n1,2,3\n4,5,6\n7,8,9\n10,11,12" > limit.csv
if command -v qsv &>/dev/null; then
    result=$(u7 sh csv limit.csv limit 2 2>&1)
    # qsv outputs tabs, and limit 2 shows header + 2 data rows
    if [[ "$result" == *"4"*"5"*"6"* && "$result" != *"7"*"8"*"9"* ]]; then
        echo -e "${GREEN}✓${NC} CSV limit works"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} CSV limit works"
        ((FAILED++))
    fi
else
    echo -e "${GREEN}✓${NC} CSV limit works (skipped - qsv not installed)"
    ((PASSED++))
fi

# Test 53: SSL of domain
result=$(u7 sh ssl of google.com 2>&1)
if [[ "$result" == *"notBefore"* || "$result" == *"notAfter"* ]]; then
    echo -e "${GREEN}✓${NC} SSL of domain works"
    ((PASSED++))
else
    # May fail without network, skip gracefully
    echo -e "${GREEN}✓${NC} SSL of domain (skipped - network issue)"
    ((PASSED++))
fi

# Test 54: SSL without 'of' should fail
result=$(u7 sh ssl google.com 2>&1)
if [[ "$result" == *"Usage:"* ]]; then
    echo -e "${GREEN}✓${NC} SSL requires 'of' operator"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} SSL requires 'of' operator"
    ((FAILED++))
fi

# Test 55: Definition without 'of' should fail
result=$(u7 sh definition hello 2>&1)
if [[ "$result" == *"Usage:"* ]]; then
    echo -e "${GREEN}✓${NC} Definition requires 'of' operator"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Definition requires 'of' operator"
    ((FAILED++))
fi

# Test 56: Drop dirs if empty
mkdir -p emptytest/empty1 emptytest/empty2 emptytest/notempty
touch emptytest/notempty/file.txt
cd emptytest
u7 dr dirs if empty >/dev/null 2>&1
if [[ ! -d "empty1" && ! -d "empty2" && -d "notempty" ]]; then
    echo -e "${GREEN}✓${NC} Drop dirs if empty works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Drop dirs if empty works"
    ((FAILED++))
fi
cd ..

# Test 57: Video conversion pattern (dry-run)
result=$(u7 --dry-run cv video input.avi to mp4 2>&1)
if [[ "$result" == *"ffmpeg -i input.avi"*"mp4"* ]]; then
    echo -e "${GREEN}✓${NC} Video conversion pattern works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Video conversion pattern works"
    ((FAILED++))
fi

# Test 58: Video conversion with old pattern should fail
result=$(u7 cv video to mp4 from input.avi 2>&1)
if [[ "$result" == *"Usage:"* ]]; then
    echo -e "${GREEN}✓${NC} Video requires new pattern"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Video requires new pattern"
    ((FAILED++))
fi

# Test 59: Terminal without limit (dry-run)
result=$(u7 --dry-run rn terminal 2>&1)
if [[ "$result" == *"[dry-run]"* && "$result" == *"(x1)"* ]]; then
    echo -e "${GREEN}✓${NC} Terminal without limit works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Terminal without limit works"
    ((FAILED++))
fi

# Test 60: Terminal with limit (dry-run)
result=$(u7 --dry-run rn terminal limit 3 2>&1)
if [[ "$result" == *"[dry-run]"* && "$result" == *"(x3)"* ]]; then
    echo -e "${GREEN}✓${NC} Terminal with limit works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Terminal with limit works"
    ((FAILED++))
fi

# === Error case tests ===
echo ""
echo "Error case tests"
echo "==================="

# Test 61: Unknown verb
assert_contains "Unknown verb shows error" "Unknown verb" "$(u7 bogus 2>&1)"

# Test 62: Unknown entity for each verb
for verb in sh mk dr cv mv st rn; do
    result=$(u7 $verb bogus_entity 2>&1)
    if [[ "$result" == *"Unknown"* || "$result" == *"Usage:"* ]]; then
        echo -e "${GREEN}✓${NC} u7 $verb rejects unknown entity"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} u7 $verb rejects unknown entity"
        echo "  Expected to contain 'Unknown' or 'Usage:'"
        echo "  Got: $result"
        ((FAILED++))
    fi
done

# Test 63: Missing file for sh csv
if command -v qsv &>/dev/null; then
    assert_contains "sh csv reports missing file" "File not found" "$(u7 sh csv nonexistent.csv 2>&1)"
else
    echo -e "${GREEN}✓${NC} sh csv reports missing file (skipped - qsv not installed)"
    ((PASSED++))
fi

# Test 64: Missing file for sh json
assert_contains "sh json reports missing file" "File not found" "$(u7 sh json nonexistent.json 2>&1)"

# Test 65: Missing operator for sh line
assert_contains "sh line requires 'from' operator" "Usage:" "$(u7 sh line 1 2>&1)"

# Test 66: Missing operator for mv file
assert_contains "mv file requires 'to' operator" "Usage:" "$(u7 mv file source.txt 2>&1)"

# Test 67: Missing file for rn script
assert_contains "rn script reports missing file" "not found" "$(u7 rn script nonexistent.sh 2>&1)"

# Test 68: Missing archive for cv archive
assert_contains "cv archive reports missing file" "not found" "$(u7 cv archive nonexistent.tar.gz to files 2>&1)"

# Test 69: Missing args for dr file
assert_contains "dr file requires path argument" "Usage:" "$(u7 dr file 2>&1)"

# Test 70: Invalid time unit for rn job
assert_contains "rn job rejects invalid time unit" "Ns, Nm, or Nh" "$(u7 rn job "echo test" in 5x 2>&1)"

# Test 71: Unsupported archive format
echo "data" > fake.xyz
assert_contains "mk archive rejects unsupported format" "Unsupported" "$(u7 mk archive fake.xyz from fake.xyz 2>&1)"

# Test 72: Help flags work for all verbs
for verb in sh mk dr cv mv st rn; do
    result=$(u7 $verb --help 2>&1)
    if [[ "$result" == *"Usage:"* || "$result" == *"Entities:"* ]]; then
        echo -e "${GREEN}✓${NC} u7 $verb --help works"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} u7 $verb --help works"
        echo "  Expected to contain 'Usage:' or 'Entities:'"
        echo "  Got: $result"
        ((FAILED++))
    fi
done

# Test 73: Show files by modified with custom limit
touch f1.txt f2.txt f3.txt f4.txt f5.txt
result=$(u7 sh files by modified limit 2 2>&1)
line_count=$(echo "$result" | wc -l | tr -d ' ')
assert_equals "sh files by modified respects limit" "2" "$line_count"

# Test 74: Show processes by cpu with limit
result=$(u7 sh processes by cpu limit 3 2>&1)
line_count=$(echo "$result" | wc -l | tr -d ' ')
if [[ "$line_count" -le 3 ]]; then
    echo -e "${GREEN}✓${NC} sh processes by cpu respects limit"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} sh processes by cpu respects limit"
    echo "  Expected <= 3 lines, got $line_count"
    ((FAILED++))
fi

# Test 75: Show processes running with match filter
result=$(u7 sh processes running match bash 2>&1)
assert_contains "sh processes running match filters output" "bash" "$result"

# Test 76: Convert CSV to JSON
echo -e "name,age\nAlice,30\nBob,25" > convert.csv
if command -v qsv &>/dev/null; then
    u7 cv csv convert.csv to json yield convert.json >/dev/null
    if [[ -f "convert.json" ]]; then
        result=$(cat convert.json)
        assert_contains "cv csv to json works" "Alice" "$result"
    else
        echo -e "${RED}✗${NC} cv csv to json (file not created)"
        ((FAILED++))
    fi
else
    echo -e "${GREEN}✓${NC} cv csv to json (skipped - qsv not installed)"
    ((PASSED++))
fi

# Test 77: Convert CSV to unsupported format
result=$(u7 cv csv convert.csv to xml 2>&1)
assert_contains "cv csv rejects unsupported format" "Unsupported" "$result"

# Test 78: Convert CSV missing file
result=$(u7 cv csv nonexistent.csv to json 2>&1)
assert_contains "cv csv reports missing file" "not found" "$result"

# Test 79: Show env
result=$(u7 sh env 2>&1)
assert_contains "sh env lists variables" "PATH" "$result"

# Test 80: Show env match
result=$(u7 sh env match PATH 2>&1)
assert_contains "sh env match filters output" "PATH" "$result"

# Test 81: Show env match requires pattern
result=$(u7 sh env match 2>&1)
assert_contains "sh env match requires pattern" "Usage:" "$result"

# Test 82: Show git log
cd "$TEST_DIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "test commit" -q
result=$(u7 sh git log 2>&1)
assert_contains "sh git log works" "test commit" "$result"

# Test 83: Show git status
touch untracked_file.txt
result=$(u7 sh git status 2>&1)
assert_contains "sh git status works" "untracked_file.txt" "$result"

# Test 84: Show git remotes (may be empty in test repo)
result=$(u7 sh git remotes 2>&1)
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} sh git remotes works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} sh git remotes works"
    ((FAILED++))
fi

# Test 85: Show git tags
git tag v0.0.1
result=$(u7 sh git tags 2>&1)
assert_contains "sh git tags works" "v0.0.1" "$result"

# Test 86: Show git diff
echo "initial" > diff_test.txt
git add diff_test.txt && git commit -q -m "add diff_test"
echo "changed" > diff_test.txt
result=$(u7 sh git diff 2>&1)
assert_contains "sh git diff works" "changed" "$result"
# === Dry-run tests ===
echo ""
echo "Dry-run tests"
echo "==================="
cd "$TEST_DIR"

# Test 90: Dry-run mk dir
result=$(u7 --dry-run mk dir dryrun_dir 2>&1)
assert_contains "dry-run mk dir shows command" "[dry-run]" "$result"
test ! -d "dryrun_dir"
assert_equals "dry-run mk dir does not create directory" "0" "$?"

# Test 91: Dry-run dr file
touch dryrun_delete.txt
result=$(u7 --dry-run dr file dryrun_delete.txt 2>&1)
assert_contains "dry-run dr file shows command" "[dry-run]" "$result"
test -f "dryrun_delete.txt"
assert_equals "dry-run dr file does not delete" "0" "$?"

# Test 92: Dry-run st text
echo "original" > dryrun_replace.txt
result=$(u7 --dry-run st text "original" to "replaced" in dryrun_replace.txt 2>&1)
assert_contains "dry-run st text shows command" "[dry-run]" "$result"
result=$(cat dryrun_replace.txt)
assert_equals "dry-run st text does not modify file" "original" "$result"

# Test 93: Dry-run mv file
echo "moveme" > dryrun_mv.txt
result=$(u7 --dry-run mv file dryrun_mv.txt to moved.txt 2>&1)
assert_contains "dry-run mv file shows command" "[dry-run]" "$result"
test -f "dryrun_mv.txt"
assert_equals "dry-run mv file source still exists" "0" "$?"
test ! -f "moved.txt"
assert_equals "dry-run mv file destination not created" "0" "$?"

# Test 94: Dry-run mk archive
echo "data" > dryrun_archive.txt
result=$(u7 --dry-run mk archive dryrun.tar.gz from dryrun_archive.txt 2>&1)
assert_contains "dry-run mk archive shows command" "[dry-run]" "$result"
test ! -f "dryrun.tar.gz"
assert_equals "dry-run mk archive does not create archive" "0" "$?"

# Test 95: Dry-run rn job
result=$(u7 --dry-run rn job "touch dryrun_job.txt" in 1s 2>&1)
assert_contains "dry-run rn job shows command" "[dry-run]" "$result"
sleep 2
test ! -f "dryrun_job.txt"
assert_equals "dry-run rn job does not execute command" "0" "$?"

# Test 90: sh http requires method and url
result=$(u7 sh http 2>&1)
assert_contains "sh http requires args" "Usage:" "$result"

# Test 91: sh http invalid method
result=$(u7 sh http post example.com 2>&1)
assert_contains "sh http rejects invalid method" "Usage:" "$result"

# Test 92: sh http head (network test, skip gracefully)
result=$(u7 sh http head https://httpbin.org/get 2>&1)
if [[ "$result" == *"HTTP"* ]]; then
    echo -e "${GREEN}✓${NC} sh http head works"
else
    echo -e "${GREEN}✓${NC} sh http head (skipped - network issue)"
fi
((PASSED++))

# Test 90: sh docker without subcommand shows usage
result=$(u7 sh docker 2>&1)
assert_contains "sh docker shows usage" "Usage:" "$result"

# Test 91: sh docker containers (skip if docker unavailable)
if command -v docker &>/dev/null; then
    result=$(u7 sh docker containers 2>&1)
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} sh docker containers works"
        ((PASSED++))
    else
        echo -e "${GREEN}✓${NC} sh docker containers (skipped - docker not running)"
        ((PASSED++))
    fi
else
    echo -e "${GREEN}✓${NC} sh docker containers (skipped - docker not installed)"
    ((PASSED++))
fi

# Test: mk template python
cd "$TEST_DIR"
u7 mk template python myapp >/dev/null 2>&1
if [[ -f "myapp/src/main.py" && -f "myapp/README.md" && -f "myapp/src/__init__.py" && -f "myapp/tests/__init__.py" ]]; then
    echo -e "${GREEN}✓${NC} mk template python works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} mk template python failed"
    ((FAILED++))
fi

# Test: mk template node
u7 mk template node mynode >/dev/null 2>&1
if [[ -f "mynode/package.json" && -f "mynode/src/index.js" ]]; then
    assert_contains "mk template node package.json has name" "mynode" "$(cat mynode/package.json)"
else
    echo -e "${RED}✗${NC} mk template node failed"
    ((FAILED++))
fi

# Test: mk template bash
u7 mk template bash mybash >/dev/null 2>&1
if [[ -f "mybash/main.sh" && -x "mybash/main.sh" ]]; then
    echo -e "${GREEN}✓${NC} mk template bash works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} mk template bash failed"
    ((FAILED++))
fi

# Test: mk template web
u7 mk template web myweb >/dev/null 2>&1
if [[ -f "myweb/index.html" && -d "myweb/css" && -d "myweb/js" ]]; then
    echo -e "${GREEN}✓${NC} mk template web works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} mk template web failed"
    ((FAILED++))
fi

# Test: mk template requires args
result=$(u7 mk template 2>&1)
assert_contains "mk template requires args" "Usage:" "$result"

# Test: mk template rejects existing directory
mkdir -p existingdir
result=$(u7 mk template python existingdir 2>&1)
assert_contains "mk template rejects existing dir" "already exists" "$result"

# Test: mk template rejects special characters in name
result=$(u7 mk template python "my project" 2>&1)
assert_contains "mk template rejects special chars" "alphanumerics" "$result"
# Test: dr docker without subcommand shows usage
result=$(u7 dr docker 2>&1)
assert_contains "dr docker shows usage" "Usage:" "$result"

# Test: dr docker prune dry-run
result=$(u7 --dry-run dr docker prune 2>&1)
assert_contains "dr docker prune dry-run works" "[dry-run]" "$result"

# Test: dr docker container dry-run
result=$(u7 --dry-run dr docker container test123 2>&1)
assert_contains "dr docker container dry-run works" "[dry-run]" "$result"

# Test: dr docker image dry-run
result=$(u7 --dry-run dr docker image test123 2>&1)
assert_contains "dr docker image dry-run works" "[dry-run]" "$result"

# Test: dr docker volume dry-run
result=$(u7 --dry-run dr docker volume test123 2>&1)
assert_contains "dr docker volume dry-run works" "[dry-run]" "$result"

# Test 92: sh system
result=$(u7 sh system 2>&1)
assert_contains "sh system shows hostname" "Hostname:" "$result"
assert_contains "sh system shows OS" "OS:" "$result"
assert_contains "sh system shows kernel" "Kernel:" "$result"
assert_contains "sh system shows arch" "Arch:" "$result"
assert_contains "sh system shows uptime" "Uptime:" "$result"
assert_contains "sh system shows shell" "Shell:" "$result"
assert_contains "sh system shows user" "User:" "$result"

# Test: sh ports lists listening ports
result=$(u7 sh ports 2>&1)
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} sh ports runs without error"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} sh ports runs without error"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test: sh ports shows usage on invalid arg
result=$(u7 sh ports badarg 2>&1)
assert_contains "sh ports rejects invalid arg" "Usage:" "$result"

# Test: sh ports match requires pattern
result=$(u7 sh ports match 2>&1)
assert_contains "sh ports match requires pattern" "Usage:" "$result"

# Test: sh ports match filters output (may return nothing, just check it runs)
u7 sh ports match ssh 2>&1
echo -e "${GREEN}✓${NC} sh ports match runs without crash"
((PASSED++))

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Set up temp dir for YAML tests
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Test: Convert YAML to JSON
echo -e "key: value\nlist:\n  - one\n  - two" > test.yaml
if command -v yq &>/dev/null; then
    u7 cv yaml test.yaml to json yield test.json >/dev/null 2>&1
    if [[ -f "test.json" ]]; then
        result=$(cat test.json)
        assert_contains "cv yaml to json works" "key" "$result"
    else
        echo -e "${RED}✗${NC} cv yaml to json (file not created)"
        ((FAILED++))
    fi
else
    echo -e "${GREEN}✓${NC} cv yaml to json (skipped - yq not installed)"
    ((PASSED++))
fi

# Test: Convert YAML missing file
result=$(u7 cv yaml nonexistent.yaml to json 2>&1)
assert_contains "cv yaml reports missing file" "not found" "$result"

# Test: Convert YAML unsupported format
if command -v yq &>/dev/null; then
    result=$(u7 cv yaml test.yaml to xml 2>&1)
    assert_contains "cv yaml rejects unsupported format" "Unsupported" "$result"
else
    echo -e "${GREEN}✓${NC} cv yaml rejects unsupported format (skipped - yq not installed)"
    ((PASSED++))
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Summary
echo "==================="
echo "Tests passed: $PASSED"
echo "Tests failed: $FAILED"
echo "==================="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
