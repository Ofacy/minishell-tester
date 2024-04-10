#!/bin/bash

# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    run.sh                                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: bwisniew <bwisniew@student.42lyon.fr>      +#+  +:+       +#+         #
#    By: lcottet <lcottet@student.42lyon.fr>      +#+#+#+#+#+   +#+            #
#                                                      #+#    #+#              #
#                                                     ###   ########.fr        #
#                                                                              #
# **************************************************************************** #


OUTPUT_EXIT=1
ERROR_EXIT=1
STATUS_EXIT=1
VALGRIND=0

# handle arguments

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--valgrind)
      VALGRIND="1"
      shift # past argument
      ;;
    -o|--ignore-output)
      OUTPUT_EXIT=0
      shift # past argument
      ;;
    -e|--ignore-error)
      ERROR_EXIT=0
      shift # past argument
      ;;
	-s|--ignore-status)
		STATUS_EXIT=0
		shift
		;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

SUCCES_NB=0

echo | valgrind --track-fds=yes --log-file=./test cat
VALGRIND_FD_NB=$(cat test | grep "FILE DESCRIPTORS" | awk '{ print $4 }')

RED="\033[31m"
BLUE="\033[34m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
GREEN="\033[32m"
CYAN="\033[36m"
GRAY="\033[1;37m"
ENDCOLOR="\033[0m"

TESTS=$(ls -v1 tests/*.sh)
if [[ $# -ne 0 ]]; then
	TESTS=$(echo $@ | sed 's/ /\n/g')
fi

NB_TEST=$(echo "$TESTS" | wc -l)
echo -e $'\n\n\n\n'"${YELLOW}Running $NB_TEST tests...${ENDCOLOR}"
VALGRIND_ARGS=
if [[ $VALGRIND -eq 1 ]]; then
	VALGRIND_ARGS="valgrind --track-fds=yes --log-file=../user_outputs/valgrind.log --leak-check=full --show-leak-kinds=all --error-exitcode=69"
	echo -e "${RED}Running with valgrind!$ENDCOLOR"
fi
if [[ OUTPUT_EXIT -eq 0 ]]; then
	echo -e "${RED}Ignoring stdout errors...$ENDCOLOR"
fi
if [[ ERROR_EXIT -eq 0 ]]; then
	echo -e "${RED}Ignoring stderr errors...$ENDCOLOR"
fi
if [[ STATUS_EXIT -eq 0 ]]; then
	echo -e "${RED}Ignoring status errors..."
fi

mkdir -p bash_outputs
mkdir -p user_outputs
OG_PWD=$(pwd)


for filename in $TESTS; do
	CMD=$(cat $filename)$'\n'exit
	echo -n -e $'\n'"${CYAN}Running test${ENDCOLOR} $filename"
	rm -rf exec_env
	mkdir -p exec_env
	cd exec_env && echo "$CMD" | bash 2> ../bash_outputs/err 1> ../bash_outputs/out
	BASH_EXIT=$?
	cd ..
	rm -rf exec_env
	mkdir -p exec_env
	cd exec_env && echo "$CMD" | $VALGRIND_ARGS ../../minishell 2> ../user_outputs/err 1> ../user_outputs/out
	USER_EXIT=$?
	cd ..
	OUT_DIFF=$(diff -U 3 bash_outputs/out user_outputs/out)
	ERR_DIFF=$(diff -U 3 bash_outputs/err user_outputs/err)
	if [[ $VALGRIND -eq 1 ]]; then
		bash valgrind_signal_remove.sh
	fi
	if [ "$OUTPUT_DIFF" != "" ]; then
		echo -e " ${RED}KO${ENDCOLOR}"
		echo -e $'\n'${YELLOW}========== ${ENDCOLOR}$filename${YELLOW} ==========${ENDCOLOR}
		cat $filename
		echo -e ${YELLOW}=====================$(seq $(echo $filename | wc -c) | xargs -I{} echo -n =)${ENDCOLOR}$'\n'
		echo "OUTPUT DIFF:"
		echo "$OUT_DIFF"
		if [[ "$OUTPUT_EXIT" -eq 1 ]]; then
			exit 1
		fi
	elif [[ $VALGRIND -eq 1 ]] && ([[ "USER_EXIT" -eq 69 || $(cat ./user_outputs/valgrind.log | grep "FILE DESCRIPTORS:" | uniq -w 1 | wc -l) -ne 1 ]] || [[ $(cat ./user_outputs/valgrind.log | grep "FILE DESCRIPTORS:" | uniq -w 1 | awk '{print $4}') -ne $VALGRIND_FD_NB ]]); then
		echo -e " ${RED}KO${ENDCOLOR}"
		echo -e $'\n'${YELLOW}========== ${ENDCOLOR}$filename${YELLOW} ==========${ENDCOLOR}
		cat $filename
		echo -e ${YELLOW}=====================$(seq $(echo $filename | wc -c) | xargs -I{} echo -n =)${ENDCOLOR}$'\n'
		echo -e $'\n'${RED}========== ${ENDCOLOR}Valgrind log${RED} ==========${ENDCOLOR}$'\n'
		cat ./user_outputs/valgrind.log
		echo -e ${RED}=====================$(seq 14 | xargs -I{} echo -n =)${ENDCOLOR}$'\n'
		if [[ "$ERROR_EXIT" -eq 1 ]]; then
			exit 1
		fi
	elif [ "$(cat user_outputs/err | wc -l)" != "$(cat bash_outputs/err | sed '/bash: line [0-9]: `/d' | wc -l)" ]; then
		echo -e " ${RED}KO${ENDCOLOR}"
		echo -e $'\n'${YELLOW}========== ${ENDCOLOR}$filename${YELLOW} ==========${ENDCOLOR}
		cat $filename
		echo -e ${YELLOW}=====================$(seq $(echo $filename | wc -c) | xargs -I{} echo -n =)${ENDCOLOR}$'\n'
		echo "ERROR DIFF:"
		echo "$ERR_DIFF"
		if [[ "$ERROR_EXIT" -eq 1 ]]; then
			exit 1
		fi
	elif [ "$BASH_EXIT" != "$USER_EXIT" ]; then
		echo -e " ${RED}KO${ENDCOLOR}"
		echo -e $'\n'${YELLOW}========== ${ENDCOLOR}$filename${YELLOW} ==========${ENDCOLOR}
		cat $filename
		echo -e ${YELLOW}=====================$(seq $(echo $filename | wc -c) | xargs -I{} echo -n =)${ENDCOLOR}$'\n'
		echo "EXIT CODE DIFF:"
		echo "Expected: $BASH_EXIT"
		echo "Got: $USER_EXIT"
		if [[ "$STATUS_EXIT" -eq 1 ]]; then
			exit 1
		fi
	else
		SUCCES_NB=$((SUCCES_NB+1))
		echo -e " ${GREEN}OK${ENDCOLOR}"
	fi
	rm user_outputs/err user_outputs/out bash_outputs/err bash_outputs/out
done

echo -e $'\n\n\n\n' ${YELLOW}Total : ${ENDCOLOR}${GREEN}$SUCCES_NB OK${ENDCOLOR}  ${CYAN}/ $NB_TEST tests ${ENDCOLOR}${RED}"("$(($NB_TEST-$SUCCES_NB)) KO")"${ENDCOLOR}.

if [[ $SUCCES_NB -eq $NB_TEST ]]; then
	echo -e $'\n' 🎉${MAGENTA} Congratulations! You passed all tests! ${ENDCOLOR}🎉 $'\n'
	exit 0
else
	exit 1
fi
