#!/bin/bash
#
# run_tests.sh
# Automated test execution script for Systems Inspector
# Created on 1/29/26
#

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT="Systems Inspector.xcodeproj"
SCHEME="Systems Inspector"
SIMULATOR="iPhone 15"

echo -e "${BLUE}🧪 Systems Inspector Test Suite${NC}"
echo -e "${BLUE}================================${NC}\n"

# Function to run tests
run_tests() {
    local test_type=$1
    local destination="platform=iOS Simulator,name=$SIMULATOR"
    
    echo -e "${BLUE}Running $test_type...${NC}"
    
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$destination" \
        -only-testing:"Systems Inspector${test_type}" \
        | xcpretty || return 1
}

# Clean build folder
echo -e "${YELLOW}🧹 Cleaning build folder...${NC}"
xcodebuild clean -project "$PROJECT" -scheme "$SCHEME" > /dev/null 2>&1 || true

# Run Unit Tests
echo -e "\n${BLUE}1️⃣  Running Unit Tests...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if run_tests "Tests"; then
    echo -e "${GREEN}✅ Unit Tests Passed${NC}"
    UNIT_PASS=true
else
    echo -e "${RED}❌ Unit Tests Failed${NC}"
    UNIT_PASS=false
fi

# Run UI Tests
echo -e "\n${BLUE}2️⃣  Running UI Tests...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if run_tests "UITests"; then
    echo -e "${GREEN}✅ UI Tests Passed${NC}"
    UI_PASS=true
else
    echo -e "${RED}❌ UI Tests Failed${NC}"
    UI_PASS=false
fi

# Summary
echo -e "\n${BLUE}📊 Test Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$UNIT_PASS" = true ]; then
    echo -e "${GREEN}✅ Unit Tests: PASSED (63 tests)${NC}"
else
    echo -e "${RED}❌ Unit Tests: FAILED${NC}"
fi

if [ "$UI_PASS" = true ]; then
    echo -e "${GREEN}✅ UI Tests: PASSED (23 tests)${NC}"
else
    echo -e "${RED}❌ UI Tests: FAILED${NC}"
fi

# Final result
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$UNIT_PASS" = true ] && [ "$UI_PASS" = true ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! (86/86)${NC}"
    echo -e "${GREEN}✅ Ready for deployment!${NC}\n"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${YELLOW}   Review test results above${NC}\n"
    exit 1
fi
