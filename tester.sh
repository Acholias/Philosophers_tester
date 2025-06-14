#!/bin/bash

TIMEOUT_DURATION=10

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

TEMP_LOG=$(mktemp)
RESULTS_LOG=$(mktemp)

handle_sigint(){
	trap '' SIGTERM
	echo -e "\n${RED}Test interrupted by the user${RESET}"
	rm -f "$TEMP_LOG" "$RESULTS_LOG"
	kill 0
	exit
}

trap handle_sigint SIGINT

declare -a TESTS_NO_DEATH=(
	"4 410 200 200"
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

if [ ! -x "./philo" ]; then
    echo -e "${RED}Error: The ./philo executable was not found in the current directory!${RESET}"
    echo -e "${RED}Please compile your project before running the tester.${RESET}"
    exit 1
fi

if [ $# -eq 0 ]; then
	echo -e "${CYAN}No argument provided, running predefined tests..${RESET}"

	NB_TESTS=${#TESTS_NO_DEATH[@]}
	echo -e "${YELLOW}== Tests where no philosopher should die ==${RESET}"
	for ((i=0; i<NB_TESTS; i++)); do
		PHILO_ARGS="${TESTS_NO_DEATH[$i]}"
		RUN_COUNT="${RUNS_NO_DEATH[$i]}"

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

		LOGIC_OK=0
		LOGIC_KO=0
		for ((index=1; index<=RUN_COUNT; index++)); do
			timeout $TIMEOUT_DURATION ./philo $PHILO_ARGS > "$TEMP_LOG" 2>&1
            if grep -q "died" "$TEMP_LOG"; then
                LINE_AFTER_DIED=$(awk '/died/ {print NR; exit}' "$TEMP_LOG")
                TOTAL_LINES=$(wc -l < "$TEMP_LOG")
                if [ "$LINE_AFTER_DIED" -lt "$TOTAL_LINES" ]; then
                    PHILO_RESULT="${RED}KO (output after died)${RESET}"
                    ((LOGIC_KO++))
                else
                    PHILO_RESULT="${GREEN}OK${RESET}"
                    ((LOGIC_OK++))
                fi
            else
                PHILO_RESULT="${RED}KO${RESET}"
                ((LOGIC_KO++))
            fi
			printf "  Logic test $index : [philo: $PHILO_RESULT]\n"
		done

		HELGRIND_OK=0
		HELGRIND_KO=0
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
fi

if [[ $1 != *" "* ]]; then
	echo -e "${RED}Error: The project arguments must be in quotes and contain several values!"
	echo -e "Example: $0 \"4 410 200 200\" [runs].${RESET}"
	exit 1
fi

PHILO_ARGS=$1

if [ $# -ge 2 ]; then
	if [[ $2 =~ ^[0-9]+$ ]]; then
		RUNS=$2
		if [ "$RUNS" -gt 1000 ]; then
			echo -e "${RED}Error: The number of runs cannot exceed 1000.${RESET}"
			exit 1
		fi
	else
		echo -e "${RED}Error: The second argument (number of runs) must be a positive integer.${RESET}"
		exit 1
	fi
else
	RUNS=5
fi

echo -e "${YELLOW}Testing your current project (logic only) ⏳⚙️:\n${RESET}"

LOGIC_OK=0
LOGIC_KO=0
for ((index=1; index<=RUNS; index++)); do
	timeout $TIMEOUT_DURATION ./philo $PHILO_ARGS > "$TEMP_LOG" 2>&1
	if grep -q "died" "$TEMP_LOG"; then
		PHILO_RESULT="${RED}KO${RESET}"
		((LOGIC_KO++))
	else
		PHILO_RESULT="${GREEN}OK${RESET}"
		((LOGIC_OK++))
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