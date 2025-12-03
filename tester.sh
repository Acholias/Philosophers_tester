#!/bin/bash

TIMEOUT_DURATION=10

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

TEMP_LOG=$(mktemp)
RESULTS_LOG=$(mktemp)

handle_sigint()
{
    trap '' SIGTERM
    echo -e "\n${RED}Test interrupted by the user${RESET}"
    rm -f "$TEMP_LOG" "$RESULTS_LOG"
    kill 0
    exit 1
}

trap handle_sigint SIGINT

display_help()
{
    echo -e "${CYAN}Usage: $0 [COMMAND | \"PHILO_ARGS\" [RUNS] [DEATH_MODE]]${RESET}"
    echo -e ""
    echo -e "${YELLOW}Description:${RESET}"
    echo -e "  This script tests the 'philo' program from the 42 Philosophers project."
    echo -e "  It can run a predefined set of tests or custom tests with specified arguments."
    echo -e ""
    echo -e "${YELLOW}Commands:${RESET}"
    echo -e "  (no arguments)        Display this help message."
    echo -e "  MANDATORY             Run all predefined tests (NO_DEATH and EXPECT_DEATH scenarios)."
    echo -e "  help, -h, --help      Display this help message and exit."
    echo -e ""
    echo -e "${YELLOW}Running custom tests:${RESET}"
    echo -e "  To run with custom arguments for './philo':"
    echo -e "    \$1: \"PHILO_ARGS\"    (Required) Quoted string of arguments for ./philo."
    echo -e "                          Example: \"4 410 200 200\""
    echo -e "    \$2: [RUNS]           (Optional) Number of times to run this specific test."
    echo -e "                          Default: 5. Must be an integer between 1 and 1000."
    echo -e "    \$3: [DEATH_MODE]     (Optional) Expected outcome regarding philosopher death."
    echo -e "                          Values: 'EXPECT_DEATH' or 'NO_DEATH'."
    echo -e "                          Default: 'NO_DEATH'."
    echo -e ""
    echo -e "${YELLOW}Examples:${RESET}"
    echo -e "  ${GREEN}Run all predefined tests:${RESET}"
    echo -e "    $0 MANDATORY"
    echo -e ""
    echo -e "  ${GREEN}Run a custom test (e.g., 4 philosophers, 410ms to die, 200ms to eat, 200ms to sleep):${RESET}"
    echo -e "    ${CYAN}Run 5 times (default), expect no death (default):${RESET}"
    echo -e "      $0 \"4 410 200 200\""
    echo -e "    ${CYAN}Run 10 times, expect no death (default):${RESET}"
    echo -e "      $0 \"4 410 200 200\" 10"
    echo -e "    ${CYAN}Run 3 times, expect death (e.g., for args \"120 200 200 200\"):${RESET}"
    echo -e "      $0 \"120 200 200 200\" 3 EXPECT_DEATH"
    echo -e ""
    echo -e "${YELLOW}Note:${RESET}"
    echo -e "  The './philo' executable must be present in the current directory and be executable."
    exit 0
}

run_predefined_tests()
{
    echo -e "${CYAN}Running predefined tests...${RESET}"

    NB_TESTS=${#TESTS_NO_DEATH[@]}
    echo -e "\n${YELLOW}== Tests where no philosopher should die ==${RESET}"
    for ((i=0; i<NB_TESTS; i++)); do
        PHILO_ARGS="${TESTS_NO_DEATH[$i]}"
        RUN_COUNT="${RUNS_NO_DEATH[$i]}"
        echo -e "${CYAN}Running test with args: [${PHILO_ARGS}] for ${RUN_COUNT} times${RESET}"

        LOGIC_OK=0
        LOGIC_KO=0
        for ((index=1; index<=RUN_COUNT; index++)); do
            timeout $TIMEOUT_DURATION ./philo $PHILO_ARGS > "$TEMP_LOG" 2>&1
            if grep -q "died" "$TEMP_LOG"; then
                PHILO_RESULT="${RED}KO${RESET}"
                ((LOGIC_KO++))
            else
                PHILO_RESULT="${GREEN}OK${RESET}"
                ((LOGIC_OK++))
            fi
            printf "  Logic test $index : [philo: $PHILO_RESULT]\n"
        done

        HELGRIND_OK=0
        HELGRIND_KO=0
        echo -e "${CYAN}Running Helgrind for args: [${PHILO_ARGS}] for ${RUN_COUNT} times${RESET}"
        for ((index=1; index<=RUN_COUNT; index++)); do
            timeout $TIMEOUT_DURATION valgrind --tool=helgrind ./philo $PHILO_ARGS > "$TEMP_LOG" 2>&1
            if grep -q "Possible data race" "$TEMP_LOG"; then
                HELGRIND_RESULT="${RED}KO${RESET}"
                ((HELGRIND_KO++))
            else
                HELGRIND_RESULT="${GREEN}OK${RESET}"
                ((HELGRIND_OK++))
            fi
            printf "  Helgrind test $index : [data race: $HELGRIND_RESULT]\n"
        done

        echo -e "${GREEN}  Logic OK: $LOGIC_OK/$RUN_COUNT${RESET}"
        echo -e "${RED}  Logic KO: $LOGIC_KO/$RUN_COUNT${RESET}"
        echo -e "${GREEN}  Helgrind OK: $HELGRIND_OK/$RUN_COUNT${RESET}"
        echo -e "${RED}  Helgrind KO: $HELGRIND_KO/$RUN_COUNT${RESET}\n"
    done

    NB_TESTS=${#TESTS_DEATH[@]}
    echo -e "${YELLOW}== Tests where a philosopher is expected to die ==${RESET}"
    for ((i=0; i<NB_TESTS; i++)); do
        PHILO_ARGS="${TESTS_DEATH[$i]}"
        RUN_COUNT="${RUNS_DEATH[$i]}"
        echo -e "${CYAN}Running test with args: [${PHILO_ARGS}] for ${RUN_COUNT} times${RESET}"

        LOGIC_OK=0
        LOGIC_KO=0
        for ((index=1; index<=RUN_COUNT; index++)); do
            timeout $TIMEOUT_DURATION ./philo $PHILO_ARGS > "$TEMP_LOG" 2>&1
            if grep -q "died" "$TEMP_LOG"; then
                LAST_DIED_LINE=$(awk '/died/ {line=NR} END {print line}' "$TEMP_LOG")
                TOTAL_LINES=$(wc -l < "$TEMP_LOG")
                if [ -n "$LAST_DIED_LINE" ] && [ "$LAST_DIED_LINE" -lt "$TOTAL_LINES" ]; then
                    PHILO_RESULT="${RED}KO (output after died)${RESET}"
                    ((LOGIC_KO++))
                else
                    PHILO_RESULT="${GREEN}OK${RESET}"
                    ((LOGIC_OK++))
                fi
            else
                PHILO_RESULT="${RED}KO (no death detected)${RESET}"
                ((LOGIC_KO++))
            fi
            printf "  Logic test $index : [philo: $PHILO_RESULT]\n"
        done

        HELGRIND_OK=0
        HELGRIND_KO=0
        echo -e "${CYAN}Running Helgrind for args: [${PHILO_ARGS}] for ${RUN_COUNT} times${RESET}"
        for ((index=1; index<=RUN_COUNT; index++)); do
            timeout $TIMEOUT_DURATION valgrind --tool=helgrind ./philo $PHILO_ARGS > "$TEMP_LOG" 2>&1
            if grep -q "Possible data race" "$TEMP_LOG"; then
                HELGRIND_RESULT="${RED}KO${RESET}"
                ((HELGRIND_KO++))
            else
                HELGRIND_RESULT="${GREEN}OK${RESET}"
                ((HELGRIND_OK++))
            fi
            printf "  Helgrind test $index : [data race: $HELGRIND_RESULT]\n"
        done

        echo -e "${GREEN}  Logic OK: $LOGIC_OK/$RUN_COUNT${RESET}"
        echo -e "${RED}  Logic KO: $LOGIC_KO/$RUN_COUNT${RESET}"
        echo -e "${GREEN}  Helgrind OK: $HELGRIND_OK/$RUN_COUNT${RESET}"
        echo -e "${RED}  Helgrind KO: $HELGRIND_KO/$RUN_COUNT${RESET}\n"
    done

    rm -f "$TEMP_LOG" "$RESULTS_LOG"
    exit 0
}

##################### All tests for mandatory part #####################

declare -a TESTS_NO_DEATH=(
    "200 410 200 200"
    "5 610 200 200"
    "200 810 400 400"
    "5 800 200 200 7"
    "133 610 200 200 15"
)
declare -a RUNS_NO_DEATH=(
    3
    3
    3
    3
    3
)

declare -a TESTS_DEATH=(
    "2 399 200 200"
    "200 130 60 80"
    "110 200 200 200"
    "50 250 200 200 8"
    "1 200 100 100"
)
declare -a RUNS_DEATH=(
    3
    3
    3
    3
    3
)

########################################################################

if [ ! -x "./philo" ]; then
    echo -e "${RED}Error: The ./philo executable was not found in the current directory!${RESET}"
    echo -e "${RED}Please compile your project before running the tester.${RESET}"
    rm -f "$TEMP_LOG" "$RESULTS_LOG"
    exit 1
fi

if [ $# -eq 0 ]; then
    display_help
    exit 0
fi

case "$1" in
    help|-h|--help)
        display_help
        ;;
    MANDATORY)
        if [ $# -eq 1 ]; then
            run_predefined_tests
        else
            echo -e "${RED}Error: 'MANDATORY' command does not accept additional arguments.${RESET}"
            echo -e "${CYAN}Usage: $0 MANDATORY${RESET}"
            echo -e "${CYAN}Run '$0 help' for all options.${RESET}"
            rm -f "$TEMP_LOG" "$RESULTS_LOG"
            exit 1
        fi
        ;;
    *)
        if [[ $1 != *" "* ]]; then
            echo -e "${RED}Error: Invalid command or project arguments not properly quoted.${RESET}"
            echo -e "If providing custom arguments, the first argument (PHILO_ARGS) must be a quoted string."
            echo -e "Example: $0 \"4 410 200 200\""
            echo -e "Run '$0 help' for available commands and full usage instructions.${RESET}"
            rm -f "$TEMP_LOG" "$RESULTS_LOG"
            exit 1
        fi

        PHILO_ARGS=$1
        RUNS=5
        DEATH_MODE="NO_DEATH"

        if [ $# -ge 2 ]; then
            if [[ ${2} =~ ^[0-9]+$ ]]; then
                RUNS=$2
                if [ "$RUNS" -le 0 ] || [ "$RUNS" -gt 1000 ]; then
                    echo -e "${RED}Error: The number of runs must be a positive integer between 1 and 1000.${RESET}"
                    rm -f "$TEMP_LOG" "$RESULTS_LOG"
                    exit 1
                fi
                if [ $# -ge 3 ]; then
                    if [[ "$3" == "EXPECT_DEATH" ]]; then
                        DEATH_MODE="EXPECT_DEATH"
                    elif [[ "$3" == "NO_DEATH" ]]; then
                        DEATH_MODE="NO_DEATH"
                    else
                        echo -e "${RED}Error: The third argument must be 'EXPECT_DEATH' or 'NO_DEATH'.${RESET}"
                        echo -e "Example: $0 \"4 410 200 200\" 5 EXPECT_DEATH.${RESET}"
                        rm -f "$TEMP_LOG" "$RESULTS_LOG"
                        exit 1
                    fi
                fi
            else
                if [[ "$2" == "EXPECT_DEATH" ]]; then
                    DEATH_MODE="EXPECT_DEATH"
                    if [ $# -ge 3 ]; then
                        echo -e "${RED}Error: Too many arguments after specifying PHILO_ARGS and DEATH_MODE directly.${RESET}"
                        echo -e "Example: $0 \"4 410 200 200\" EXPECT_DEATH"
                        rm -f "$TEMP_LOG" "$RESULTS_LOG"
                        exit 1
                    fi
                elif [[ "$2" == "NO_DEATH" ]]; then
                    DEATH_MODE="NO_DEATH"
                     if [ $# -ge 3 ]; then
                        echo -e "${RED}Error: Too many arguments after specifying PHILO_ARGS and DEATH_MODE directly.${RESET}"
                        echo -e "Example: $0 \"4 410 200 200\" NO_DEATH"
                        rm -f "$TEMP_LOG" "$RESULTS_LOG"
                        exit 1
                    fi
                else
                    echo -e "${RED}Error: The second argument (number of runs) must be a positive integer, or 'EXPECT_DEATH'/'NO_DEATH'.${RESET}"
                    echo -e "Example: $0 \"4 410 200 200\" 5 [EXPECT_DEATH|NO_DEATH].${RESET}"
                    echo -e "Or: $0 \"4 410 200 200\" [EXPECT_DEATH|NO_DEATH].${RESET}"
                    rm -f "$TEMP_LOG" "$RESULTS_LOG"
                    exit 1
                fi
            fi
        fi

        echo -e "${YELLOW}Testing your current project with custom arguments ⏳⚙️:\n${RESET}"
        echo -e "${CYAN}Arguments: [$PHILO_ARGS], Runs: $RUNS, Death expectation: $DEATH_MODE${RESET}"

        LOGIC_OK=0
        LOGIC_KO=0
        for ((index=1; index<=RUNS; index++)); do
            timeout $TIMEOUT_DURATION ./philo $PHILO_ARGS > "$TEMP_LOG" 2>&1
            if [[ "$DEATH_MODE" == "EXPECT_DEATH" ]]; then
                if grep -q "died" "$TEMP_LOG"; then
                    LAST_DIED_LINE=$(awk '/died/ {line=NR} END {print line}' "$TEMP_LOG")
                    TOTAL_LINES=$(wc -l < "$TEMP_LOG")
                    if [ -n "$LAST_DIED_LINE" ] && [ "$LAST_DIED_LINE" -lt "$TOTAL_LINES" ]; then
                        PHILO_RESULT="${RED}KO (output after died)${RESET}"
                        ((LOGIC_KO++))
                    else
                        PHILO_RESULT="${GREEN}OK${RESET}"
                        ((LOGIC_OK++))
                    fi
                else
                    PHILO_RESULT="${RED}KO (no death detected)${RESET}"
                    ((LOGIC_KO++))
                fi
            else # NO_DEATH
                if grep -q "died" "$TEMP_LOG"; then
                    PHILO_RESULT="${RED}KO${RESET}"
                    ((LOGIC_KO++))
                else
                    PHILO_RESULT="${GREEN}OK${RESET}"
                    ((LOGIC_OK++))
                fi
            fi
            printf "Logic test $index: [philo: $PHILO_RESULT]\n"
        done

        echo -e "\n${YELLOW}Testing with Helgrind (data race only):\n${RESET}"

        HELGRIND_OK=0
        HELGRIND_KO=0
        for ((index=1; index<=RUNS; index++)); do
            timeout $TIMEOUT_DURATION valgrind --tool=helgrind ./philo $PHILO_ARGS > "$TEMP_LOG" 2>&1
            if grep -q "Possible data race" "$TEMP_LOG"; then
                HELGRIND_RESULT="${RED}KO${RESET}"
                ((HELGRIND_KO++))
            else
                HELGRIND_RESULT="${GREEN}OK${RESET}"
                ((HELGRIND_OK++))
            fi
            printf "Helgrind test $index: [data race: $HELGRIND_RESULT]\n"
        done

        echo -e "\n${GREEN}✔ Logic OK: $LOGIC_OK/${RUNS}${RESET}"
        echo -e "${RED}✘ Logic KO: $LOGIC_KO/${RUNS}${RESET}"
        echo -e "${GREEN}✔ Helgrind OK: $HELGRIND_OK/${RUNS}${RESET}"
        echo -e "${RED}✘ Helgrind KO: $HELGRIND_KO/${RUNS}${RESET}"

        rm -f "$TEMP_LOG" "$RESULTS_LOG"
        exit 0
        ;;
esac
