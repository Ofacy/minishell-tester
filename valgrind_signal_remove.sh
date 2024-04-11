output=$(cat user_outputs/valgrind.log)

while [[ $(echo "${output}" | grep "Process terminating with default action of signal 13 (SIGPIPE)") != "" ]]; do
	start=$(echo -e "${output}" | grep "Process terminating with default action of signal 13 (SIGPIPE)" | head -n 1 | awk '{{print $1}}')
	output=$(echo "$output" | sed "/$start/d")
done
OUT=$(cat user_outputs/out)
OUT_BASH=$(cat bash_outputs/out)
echo "$OUT" | grep -v "LD_PRELOAD=" | grep -v "GLIBCPP_FORCE_NEW=" | grep -v "GLIBCXX_FORCE_NEW=" > user_outputs/out
echo "$OUT_BASH" > bash_outputs/out
echo "${output}" > user_outputs/valgrind.log
