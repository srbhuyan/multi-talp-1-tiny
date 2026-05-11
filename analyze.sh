#!/bin/bash

usage()
{
  echo "Usage: $0 <algorithm> <iva> <iva data> <iva data file> <core count file> <power profile file> <time serial analytics file> <time parallel analytics file> <time parallel slow analytics file> <space serial analytics file> <space parallel analytics file> <power serial analytics file> <power parallel analytics file> <energy serial analytics file> <energy parallel analytics file> <speedup analytics file> <freeup analytics file> <powerup analytics file> <energyup analytics file> <id> <repo> <repo name> <start time> <progress> <thmgr api> <thmgr lib dir>"
  exit 1
}

check_abort() {
  local repo_path=$1
  local abort_file="$repo_path/do.abort"

  echo "[$$] Checking for abort signal in $abort_file"

  if [[ ! -f "$abort_file" ]]; then
    return 1
  fi

  local flag=$(cat "$abort_file" 2>/dev/null | tr -d '[:space]' | tr '[:upper]' '[:lower]')
  echo "[$$] Abort signal found: $flag"

  if [[ "$flag" == "1" || "$flag" == "true" || "$flag" == "abort" ]]; then
    echo "[$$] abort signal detected, terminating.."

    # if [[ -d "$repo_path" ]]; then
    #   rm -rf "$repo_path"
    #   echo "[$$] Repository directory cleaned up : $repo_path"
    # fi

    return 0
  fi

  return 1
}

call_fit() {
  local in_file=$1
  local out_file=$2
  local progress=$3
  local progress_bandwidth=$4
  local fit_count=$5
  local id=$6
  local repo=$7
  local repo_name=$8
  local start_time=$9
  local analysis_file=${10}
  local poly_only=${11}

#  fit.py --in-file "${1}" --out-file "${2}" --format csv
  if [ "$poly_only" = "true" ]; then
    fit-multivar.py --data "${in_file}" --model "${in_file%.*}.pkl" --visualization "${in_file%.*}.png" --poly-only
  else
    fit-multivar.py --data "${in_file}" --model "${in_file%.*}.pkl" --visualization "${in_file%.*}.png"
  fi
  predict.py --model "${in_file%.*}.pkl" --data "${in_file}" --format json --output "${out_file}" --output-header

  progress=`echo "scale=1; p=$progress; bw=$progress_bandwidth; l=$fit_count; p + (bw/l)" | bc -l`

  echo "{\"id\":\"$id\",\"repo\":\"$repo\",\"repoName\":\"$repo_name\",\"startTime\":\"$start_time\",\
  \"endTime\":\"\",\"status\":\"In progress\",\"progress\":{\"currentStep\":\"Predictive Model Generation\",\
  \"nextStep\":\"None\",\"percent\":$progress},\
  \"result\":{\"errorCode\":0,\"message\":\"\",\"repo\":\"\"}}" > $analysis_file
}

if [ "$#" -ne 32 ]; then
    echo "Invalid number of parameters. Expected:32 Passed:$#"
    usage
fi

algo=$1
main_file=$2
target_fn=$3
target_fn_iva_name=$4
target_fn_iva_start=$5
target_fn_iva_end=$6
argc=$7
iva_name=$8
iva_data=$9
iva_data_file=${10}
core_count_file=${11}
power_profile_file=${12}
time_serial_analytics_file=${13}
time_parallel_analytics_file=${14}
time_parallel_slow_analytics_file=${15}
space_serial_analytics_file=${16}
space_parallel_analytics_file=${17}
power_serial_analytics_file=${18}
power_parallel_analytics_file=${19}
energy_serial_analytics_file=${20}
energy_parallel_analytics_file=${21}
speedup_analytics_file=${22}
freeup_analytics_file=${23}
powerup_analytics_file=${24}
energyup_analytics_file=${25}
id=${26}
repo=${27}
repo_name=${28}
start_time=${29}
progress=${30}
thmgr_api=${31}
thmgr_lib_dir=${32}

data_file_base="${iva_data_file%.csv}"
data_id="${data_file_base#data.}"

serial_measurement="${data_id}.serial.csv"
parallel_measurement="${data_id}.parallel.csv"
parallel_slow_measurement="${data_id}.parallel_slow.csv"
analysis_file="${data_id}.analysis.json"

# parallel code generation config
parallel_plugin_so=MyRewriter.so
parallel_plugin_name=rew

echo "========================================================================="
echo "data_id = $data_id"
echo "========================================================================="


echo "cleaning up"

# cleanup
rm -f $time_serial_analytics_file $time_parallel_analytics_file $time_parallel_slow_analytics_file $space_serial_analytics_file \
   $space_parallel_analytics_file $power_serial_analytics_file $power_parallel_analytics_file \
   $energy_serial_analytics_file $energy_parallel_analytics_file $speedup_analytics_file \
   $freeup_analytics_file $powerup_analytics_file $energyup_analytics_file \
   $serial_measurement $parallel_measurement $parallel_slow_measurement

echo "cleanup done"

{ IFS=, read -ra iva_arr_names; readarray -t iva_arr; } < $iva_data_file
readarray -t core_arr < $core_count_file

echo "read array files"

power_profile=()

while IFS=, read -r i p;
do power_profile+=($p);
done < $power_profile_file

core=()

for i in ${core_arr[@]}
do
  core+=($i)
done

# Extract first column from iva_arr for analytics JSON outputs
iva_first=()
for line in "${iva_arr[@]}"
do
  IFS=, read -ra cols <<< "$line"
  iva_first+=("${cols[0]}")
done

# generate compile_commands.json
repo_path="/data/repo-import/$repo_name"

json_output=$(jq -n \
  --arg dir "$repo_path" \
  '[
     {
       "directory": $dir,
       "command": "clang-18 -g -O0 -I/usr/include -c main_original.c",
       "file": "main_original.c"
     }
   ]')

# Output the JSON to a file
echo "$json_output" > compile_commands.json
echo "JSON data written to compile_commands.json"

if [ "$data_id" == "xCtVR3p7" ]; then
# TALP coverage generation - start
echo "TALP coverage generation"

cp main_original.c main_original.bak.c
argv-to-klee main_original.c > main_original.c.tmp && mv main_original.c.tmp main_original.c

if docker exec talp-cov sh -c "cd $repo_path && analyze main_original.c"; then
  echo "TALP coverage generated successfully"
else
  echo "TALP coverage generation failed with exit code $?"
fi

# Keeping a copy of the KLEE instrumented file for debugging
cp main_original.c main_original.c.klee
mv main_original.bak.c main_original.c

for dir in klee-out-*-replay-*; do
    if [ -d "$dir" ]; then
        klee_dir="$dir"
        break
    fi
done
echo "$klee_dir"

cov-callgraph-generator --cov-file "$klee_dir/test000001-replay/test000001.cov" --output-file test000001.covgraph.json -p .
cov-callgraph-generator --cov-file "$klee_dir/test000002-replay/test000001.cov" --output-file test000001.covgraph.json -p .
# TALP coverage generation - end
fi

# Generate parallel analysis
#/usr/bin/clang-18 -g -emit-llvm -S -o main_original.ll main_original.c
#/usr/bin/opt-18 -load-pass-plugin=GanymedeAnalysisPlugin.so -passes="ganymede-analysis" main_original.ll

# Generate standalone parallel code
#/usr/bin/ganymede-codegen --analysis-file=parallelization_analysis.json --codegen-type=standalone main_original.c > main.c

# HACK - START
# HACK - fusion currently supports a standalone threadpool
# HACK - Remove when fusion supports a shared threadpool

# Generate thread manager parallel code
#/usr/bin/ganymede-codegen --analysis-file=parallelization_analysis.json --codegen-type=thmgr main_original.c > main_service.c
#cp main.c main_service.c
#sed -i 's/main(int/main_worker(int/' main_service.c
#sed -i 's/atoi(argv\[argc-1\])/atoi(argv[argc-2])/' main_service.c

# HACK -END

if [ "$data_id" == "xCtVR3p7" ]; then
# make - serial
make -f Makefile-serial
fi

# make a copy of original main file
main_file_extn="${main_file##*.}"
main_file_noextn="${main_file%.*}"
main_file_orig="$main_file_noextn"_original."$main_file_extn"
#cp $main_file $main_file_orig

# make a copy of original execuatble
algo_orig="$algo"_original
#mv $algo $algo_orig

if [ "$data_id" == "xCtVR3p7" ]; then
# make - parallel
make -f Makefile-parallel

# make - thread manager service
make -f Makefile-thmgr repo_name=$repo_name lib_location=$thmgr_lib_dir
fi

# serial run

time_serial=()
space_serial=()
power_serial=()
energy_serial=()

repo_path="/app/data/repo-import/$repo_name"

if check_abort $repo_path; then exit 2; fi

# time - serial
progress_bandwidth=10

echo "starting.."

for iva_line in "${iva_arr[@]}"
do
  # Parse CSV line into array
  IFS=, read -ra iva_cols <<< "$iva_line"

  # time
  start=`date +%s.%N`;\
  ./$algo_orig ${iva_cols[@]};\
  end=`date +%s.%N`;\
  time_serial+=(`printf '%.8f' $( echo "$end - $start" | bc -l )`);

  progress=`echo "scale=1; p=$progress; bw=$progress_bandwidth; l=${#iva_arr[@]}; p + (bw/l)" | bc -l`

  echo "{\"id\":\"$id\",\"repo\":\"$repo\",\"repoName\":\"$repo_name\",\"startTime\":\"$start_time\",\
  \"endTime\":\"\",\"status\":\"In progress\",\"progress\":{\"currentStep\":\"Serial Time Measurement\",\
  \"nextStep\":\"Serial Memory Measurement\",\"percent\":$progress},\
  \"result\":{\"errorCode\":0,\"message\":\"\",\"repo\":\"\"}}" > $analysis_file
done

if check_abort $repo_path; then exit 2; fi

# memory - serial
progress_bandwidth=10

count=1
for iva_line in "${iva_arr[@]}"
do
  # Parse CSV line into array
  IFS=, read -ra iva_cols <<< "$iva_line"

  # memory
  heaptrack -o "$algo.$count" ./$algo_orig ${iva_cols[@]};\
  space_serial+=(`heaptrack --analyze "$algo.$count.zst"  | grep "peak heap memory consumption" | awk '{print $5}'`);
  count=$((count+1))

  progress=`echo "scale=1; p=$progress; bw=$progress_bandwidth; l=${#iva_arr[@]}; p + (bw/l)" | bc -l`

  echo "{\"id\":\"$id\",\"repo\":\"$repo\",\"repoName\":\"$repo_name\",\"startTime\":\"$start_time\",\
  \"endTime\":\"\",\"status\":\"In progress\",\"progress\":{\"currentStep\":\"Serial Memory Measurement\",\
  \"nextStep\":\"Serial Power Measurement\",\"percent\":$progress},\
  \"result\":{\"errorCode\":0,\"message\":\"\",\"repo\":\"\"}}" > $analysis_file

done

if check_abort $repo_path; then exit 2; fi

# power - serial
progress_bandwidth=10

for iva_line in "${iva_arr[@]}"
do
  # power
  power_serial+=(${power_profile[0]})

  progress=`echo "scale=1; p=$progress; bw=$progress_bandwidth; l=${#iva_arr[@]}; p + (bw/l)" | bc -l`

  echo "{\"id\":\"$id\",\"repo\":\"$repo\",\"repoName\":\"$repo_name\",\"startTime\":\"$start_time\",\
  \"endTime\":\"\",\"status\":\"In progress\",\"progress\":{\"currentStep\":\"Serial Power Measurement\",\
  \"nextStep\":\"Parallel Time Measurement\",\"percent\":$progress},\
  \"result\":{\"errorCode\":0,\"message\":\"\",\"repo\":\"\"}}" > $analysis_file

done

if check_abort $repo_path; then exit 2; fi

# energy - serial
for i in "${!iva_arr[@]}"
do
  # energy
  energy_serial+=(`echo "tm=${time_serial[i]};pw=${power_serial[i]};tm * pw" | bc -l`);
done

# serial measurement file
for i in "${!iva_arr[@]}"
do
  echo "${iva_arr[i]},${time_serial[i]},${space_serial[i]},${power_serial[i]},${energy_serial[i]}" >> "$serial_measurement"
done

# parallel run

if check_abort $repo_path; then exit 2; fi

time_parallel=()
space_parallel=()
power_parallel=()
energy_parallel=()

# Add new parallel slow measurement arrays
time_parallel_slow=()

# time - parallel
progress_bandwidth=10

# Configuration
POLL_INTERVAL=3    # seconds between polls
MAX_ATTEMPTS=100   # maximum number of polling attempts
TIMEOUT=10         # curl timeout in seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Condition checking
poll_api_until_condition() {
    local url="$1"
    local condition_field="$2"
    local condition="$3"
    local attempt=1
    local -n response_body_ref=$4

    log "Polling API ${url} until condition '${condition}' is found in '${condition_field}'"

    while [ $attempt -le $MAX_ATTEMPTS ]; do
        log "${YELLOW}Attempt ${attempt}/${MAX_ATTEMPTS}${NC}"

        response=$(curl -s -w "\n%{http_code}" --connect-timeout $TIMEOUT --max-time $TIMEOUT "$url")

        if [ $? -eq 0 ]; then
            http_code=$(echo "$response" | tail -n1)
            response_body=$(echo "$response" | sed '$d')
            response_body_ref="$response_body"

            if [ "$http_code" -eq 200 ]; then
                log "Response: ${response_body}"

                # Check if condition is met (simple string matching)
                if [ $(echo "$response_body" | jq $condition_field | tr -d '"') = "$condition" ]; then
                    log "${GREEN}✓ Condition '${condition}' found!${NC}"
                    return 0
                else
                    log "Condition '${condition}' not found yet"
                fi
            else
                log "${RED}✗ API returned status ${http_code}${NC}"
            fi
        else
            log "${RED}✗ API call failed${NC}"
        fi

        if [ $attempt -eq $MAX_ATTEMPTS ]; then
            log "${RED}Maximum attempts reached. Condition not found.${NC}"
            return 1
        fi

        sleep $POLL_INTERVAL
        ((attempt++))
    done
}

if [ "$data_id" == "xCtVR3p7" ]; then
# lib load
load_response=$(curl -s -X POST -H "Content-Type: application/json" -d @- $thmgr_api/load <<EOF
{
  "repo": "$repo_name"
}
EOF
)

echo "load response = $load_response"
fi

#input_var_names=(num_samples mandel_size max_iter num_intervals rt_size pw_len)
#input_var_values=(40000000 4000 4000 40000000 2000 6)

input_var_names=(operation row col)
if [ "$data_id" == "xCtVR3p7" ]; then
  input_var_values=(1 400 400)
elif [ "$data_id" == "GHgs5fsH" ]; then
  input_var_values=(0 400 400)
fi


# lib run
for i in ${core[@]}
do
  # time
  run_response=$(curl -s -X POST -H "Content-Type: application/json" -d @- $thmgr_api/run <<EOF
{
  "repo": "$repo_name",
  "core": $i,
  "argv": ["main", $(printf '"%s", ' "${input_var_values[@]}")"$i"]
}
EOF
)

  job_id=$(echo $run_response | jq '.id' | tr -d '"')
  poll_api_until_condition "$thmgr_api/job/$job_id" ".data.attributes.status" "complete" response_body

  start=`date -d "$(echo $response_body | jq '.data.attributes.start_time' | tr -d '"')" +%s.%N`
  end=`date -d "$(echo $response_body | jq '.data.attributes.end_time' | tr -d '"')" +%s.%N`
  time_parallel+=(`printf '%.8f' $( echo "$end - $start" | bc -l )`)

  progress=`echo "scale=1; p=$progress; bw=$progress_bandwidth; l=${#core[@]}; p + (bw/l)" | bc -l`

  echo "{\"id\":\"$id\",\"repo\":\"$repo\",\"repoName\":\"$repo_name\",\"startTime\":\"$start_time\",\
  \"endTime\":\"\",\"status\":\"In progress\",\"progress\":{\"currentStep\":\"Parallel Time Measurement\",\
  \"nextStep\":\"Parallel Slow Time Measurement\",\"percent\":$progress},\
  \"result\":{\"errorCode\":0,\"message\":\"\",\"repo\":\"\"}}" > $analysis_file
done

if check_abort $repo_path; then exit 2; fi

# time - parallel slow
progress_bandwidth=10

for i in ${core[@]}
do
  # time using direct execution
  start=`date +%s.%N`;\
  ./$algo ${input_var_values[@]} $i;\
  end=`date +%s.%N`;\
  time_parallel_slow+=(`printf '%.8f' $( echo "$end - $start" | bc -l )`);

  progress=`echo "scale=1; p=$progress; bw=$progress_bandwidth; l=${#core[@]}; p + (bw/l)" | bc -l`

  echo "{\"id\":\"$id\",\"repo\":\"$repo\",\"repoName\":\"$repo_name\",\"startTime\":\"$start_time\",\
  \"endTime\":\"\",\"status\":\"In progress\",\"progress\":{\"currentStep\":\"Parallel Slow Time Measurement\",\
  \"nextStep\":\"Parallel Memory Measurement\",\"percent\":$progress},\
  \"result\":{\"errorCode\":0,\"message\":\"\",\"repo\":\"\"}}" > $analysis_file
done

if check_abort $repo_path; then exit 2; fi

# memory - parallel
progress_bandwidth=10

count=1
for i in ${core[@]}
do
  # memory
  heaptrack -o "$algo.$count" ./$algo ${input_var_values[@]} $i;\
  space_parallel+=(`heaptrack --analyze "$algo.$count.zst"  | grep "peak heap memory consumption" | awk '{print $5}'`);
  count=$((count+1))

  progress=`echo "scale=1; p=$progress; bw=$progress_bandwidth; l=${#core[@]}; p + (bw/l)" | bc -l`

  echo "{\"id\":\"$id\",\"repo\":\"$repo\",\"repoName\":\"$repo_name\",\"startTime\":\"$start_time\",\
  \"endTime\":\"\",\"status\":\"In progress\",\"progress\":{\"currentStep\":\"Parallel Memory Measurement\",\
  \"nextStep\":\"Parallel Power Measurement\",\"percent\":$progress},\
  \"result\":{\"errorCode\":0,\"message\":\"\",\"repo\":\"\"}}" > $analysis_file

done

if check_abort $repo_path; then exit 2; fi

# power - parallel
progress_bandwidth=10

for i in ${core[@]}
do
  # power
  power_parallel+=(${power_profile[i-1]})

  progress=`echo "scale=1; p=$progress; bw=$progress_bandwidth; l=${#core[@]}; p + (bw/l)" | bc -l`

  echo "{\"id\":\"$id\",\"repo\":\"$repo\",\"repoName\":\"$repo_name\",\"startTime\":\"$start_time\",\
  \"endTime\":\"\",\"status\":\"In progress\",\"progress\":{\"currentStep\":\"Parallel Power Measurement\",\
  \"nextStep\":\"Predictive Model Generation\",\"percent\":$progress},\
  \"result\":{\"errorCode\":0,\"message\":\"\",\"repo\":\"\"}}" > $analysis_file
done

if check_abort $repo_path; then exit 2; fi

# energy - parallel
for i in "${!core[@]}"
do
  # energy
  energy_parallel+=(`echo "tm=${time_parallel[i]};pw=${power_parallel[i]};tm * pw" | bc`);
done

if check_abort $repo_path; then exit 2; fi

# parallel measurement file
for i in "${!core[@]}"
do
  echo "${core[i]},${time_parallel[i]},${space_parallel[i]},${power_parallel[i]},${energy_parallel[i]}" >> "$parallel_measurement"
done

if check_abort $repo_path; then exit 2; fi

# parallel slow measurement file
for i in "${!core[@]}"
do
  echo "${core[i]},${time_parallel_slow[i]}" >> "$parallel_slow_measurement"
done

if check_abort $repo_path; then exit 2; fi

# data prep
for i in "${!space_serial[@]}"; do
  if [[ ${space_serial[$i]: -1} == "K" ]]; then
    val=${space_serial[$i]::-1}
    space_serial[$i]=`printf '%.4f' $(echo "v=$val;v * 0.001" | bc)`
  else
    space_serial[$i]=${space_serial[$i]::-1}
  fi
done

for i in "${!space_parallel[@]}"; do
  if [[ ${space_parallel[$i]: -1} == "K" ]]; then
    val=${space_parallel[$i]::-1}
    space_parallel[$i]=`printf '%.4f' $(echo "v=$val;v * 0.001" | bc)`
  else
    space_parallel[$i]=${space_parallel[$i]::-1}
  fi
done

# speedup
speedup=()
t_max=${time_parallel[0]}
for t in "${time_parallel[@]}"; do
  speedup+=(`echo "scale=2;$t_max/$t" | bc`)
done

# freeup
freeup=()
s_max=${space_parallel[0]}
for s in "${space_parallel[@]}"; do
  freeup+=(`echo "scale=2;$s_max/$s" | bc`)
done

# powerup
powerup=()
p_1=${power_parallel[0]}
for p_core in "${power_parallel[@]}"; do
  powerup+=(`echo "scale=4;$p_1/$p_core" | bc`)
done

# energyup
energyup=()
e_1=${energy_parallel[0]}
for e_core in "${energy_parallel[@]}"; do
  energyup+=(`echo "scale=4;$e_1/$e_core" | bc`)
done

# Generate CSV files for fit.py
# ${data_id}.time-serial.csv
#echo "$iva_name,size,time" > ${data_id}.time-serial.csv
echo "$(IFS=,; echo "${input_var_names[*]}"),time" > ${data_id}.time-serial.csv
for i in "${!iva_arr[@]}"; do
  # Extract all columns from the row for multivariate fitting
  echo "${iva_arr[$i]},${time_serial[$i]}" >> ${data_id}.time-serial.csv
done
# Sort by time column (last column)
FILE="${data_id}.time-serial.csv"
NCOLS=$(head -1 "$FILE" | awk -F',' '{print NF}')
(head -n 1 "$FILE" && tail -n +2 "$FILE" | sort -t',' -k"$NCOLS" -n) > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

# ${data_id}.time-parallel.csv
echo "core,time" > ${data_id}.time-parallel.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${time_parallel[$i]}" >> ${data_id}.time-parallel.csv
done

# ${data_id}.time-parallel-slow.csv
echo "core,time" > ${data_id}.time-parallel-slow.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${time_parallel_slow[$i]}" >> ${data_id}.time-parallel-slow.csv
done

# ${data_id}.space-serial.csv
echo "$(IFS=,; echo "${input_var_names[*]}"),memory" > ${data_id}.space-serial.csv
for i in "${!iva_arr[@]}"; do
  # Extract all columns from the row for multivariate fitting
  echo "${iva_arr[$i]},${space_serial[$i]}" >> ${data_id}.space-serial.csv
done
# Sort by memory column (last column)
FILE="${data_id}.space-serial.csv"
NCOLS=$(head -1 "$FILE" | awk -F',' '{print NF}')
(head -n 1 "$FILE" && tail -n +2 "$FILE" | sort -t',' -k"$NCOLS" -n) > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

# ${data_id}.space-parallel.csv
echo "core,memory" > ${data_id}.space-parallel.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${space_parallel[$i]}" >> ${data_id}.space-parallel.csv
done

# ${data_id}.power-serial.csv
echo "$(IFS=,; echo "${input_var_names[*]}"),power" > ${data_id}.power-serial.csv
for i in "${!iva_arr[@]}"; do
  # Extract all columns from the row for multivariate fitting
  echo "${iva_arr[$i]},${power_serial[$i]}" >> ${data_id}.power-serial.csv
done
# Sort by power column (last column)
FILE="${data_id}.power-serial.csv"
NCOLS=$(head -1 "$FILE" | awk -F',' '{print NF}')
(head -n 1 "$FILE" && tail -n +2 "$FILE" | sort -t',' -k"$NCOLS" -n) > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

# ${data_id}.power-parallel.csv
echo "core,power" > ${data_id}.power-parallel.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${power_parallel[$i]}" >> ${data_id}.power-parallel.csv
done

# ${data_id}.energy-serial.csv
echo "$(IFS=,; echo "${input_var_names[*]}"),energy" > ${data_id}.energy-serial.csv
for i in "${!iva_arr[@]}"; do
  # Extract all columns from the row for multivariate fitting
  echo "${iva_arr[$i]},${energy_serial[$i]}" >> ${data_id}.energy-serial.csv
done
# Sort by energy column (last column)
FILE="${data_id}.energy-serial.csv"
NCOLS=$(head -1 "$FILE" | awk -F',' '{print NF}')
(head -n 1 "$FILE" && tail -n +2 "$FILE" | sort -t',' -k"$NCOLS" -n) > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

# ${data_id}.energy-parallel.csv
echo "core,energy" > ${data_id}.energy-parallel.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${energy_parallel[$i]}" >> ${data_id}.energy-parallel.csv
done

# ${data_id}.speedup.csv
echo "core,time" > ${data_id}.speedup.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${speedup[$i]}" >> ${data_id}.speedup.csv
done

# ${data_id}.freeup.csv
echo "core,memory" > ${data_id}.freeup.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${freeup[$i]}" >> ${data_id}.freeup.csv
done

# ${data_id}.powerup.csv
echo "core,power" > ${data_id}.powerup.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${powerup[$i]}" >> ${data_id}.powerup.csv
done

# ${data_id}.energyup.csv
echo "core,energy" > ${data_id}.energyup.csv
for i in "${!core[@]}"; do
  echo "${core[$i]},${energyup[$i]}" >> ${data_id}.energyup.csv
done

if check_abort $repo_path; then exit 2; fi

# curve fitting

progress_bandwidth=10
fit_count=13
analysis_types_allow_poly_only=("${data_id}.time-serial" "${data_id}.time-parallel" "${data_id}.space-serial" "${data_id}.space-parallel" "${data_id}.power-serial" "${data_id}.energy-serial" "${data_id}.energy-parallel" "${data_id}.speedup" "${data_id}.freeup" "${data_id}.energyup")
analysis_types_allow_all=("${data_id}.power-parallel" "${data_id}.powerup")

for i in "${analysis_types_allow_poly_only[@]}"
do
  echo "${i}.csv"
  echo "${i}-fitted.json"
  call_fit $i.csv $i-fitted.json $progress $progress_bandwidth $fit_count $id $repo $repo_name "$start_time" $analysis_file "true"
done

for i in "${analysis_types_allow_all[@]}"
do
  echo "${i}.csv"
  echo "${i}-fitted.json"
  call_fit $i.csv $i-fitted.json $progress $progress_bandwidth $fit_count $id $repo $repo_name "$start_time" $analysis_file
done

# Build iva JSON array from iva_arr and iva_arr_names
iva_json_parts=()
for col_idx in "${!iva_arr_names[@]}"; do
  col_data=()
  for line in "${iva_arr[@]}"; do
    IFS=, read -ra cols <<< "$line"
    col_data+=("${cols[$col_idx]}")
  done
  iva_json_parts+=("$(jo data="$(jo -a ${col_data[@]})" name="${iva_arr_names[$col_idx]}" unit=size)")
done
iva_json="$(jo -a "${iva_json_parts[@]}")"

# time serial
extn="${time_serial_analytics_file##*.}"
noextn="${time_serial_analytics_file%.*}"

time_serial_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$iva_json" \
measurements=$(jo data=$(jo -a ${time_serial[@]}) name=time unit=seconds) \
fitted=$(jo data="`jq '.fitted' ${data_id}.time-serial-fitted.json`" name=time unit=seconds) \
unoptimized=$(jo data=$(jo -a) name=time unit=seconds) \
fit_method="`jq -r '.method' ${data_id}.time-serial-fitted.json`" \
mse="`jq '.mse' ${data_id}.time-serial-fitted.json`" \
> $time_serial_analytics_file_d

# time parallel
extn="${time_parallel_analytics_file##*.}"
noextn="${time_parallel_analytics_file%.*}"

time_parallel_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$(jo -a "$(jo data="$(jo -a ${core[@]})" name=core unit=count)")" \
measurements=$(jo data=$(jo -a ${time_parallel[@]}) name=time unit=seconds) \
unoptimized=$(jo data=$(jo -a ${time_parallel_slow[@]}) name=time unit=seconds) \
fitted=$(jo data="`jq '.fitted' ${data_id}.time-parallel-fitted.json`" name=time unit=seconds) \
fit_method="`jq -r '.method' ${data_id}.time-parallel-fitted.json`" \
mse="`jq '.mse' ${data_id}.time-parallel-fitted.json`" \
> $time_parallel_analytics_file_d

# memory serial
extn="${space_serial_analytics_file##*.}"
noextn="${space_serial_analytics_file%.*}"

space_serial_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$iva_json" \
measurements=$(jo data=$(jo -a ${space_serial[@]}) name=memory unit=MB) \
unoptimized=$(jo data=$(jo -a) name=memory unit=MB) \
fitted=$(jo data="`jq '.fitted' ${data_id}.space-serial-fitted.json`" name=memory unit=MB) \
fit_method="`jq -r '.method' ${data_id}.space-serial-fitted.json`" \
mse="`jq '.mse' ${data_id}.space-serial-fitted.json`" \
> $space_serial_analytics_file_d

# memory parallel
extn="${space_parallel_analytics_file##*.}"
noextn="${space_parallel_analytics_file%.*}"

space_parallel_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$(jo -a "$(jo data="$(jo -a ${core[@]})" name=core unit=count)")" \
measurements=$(jo data=$(jo -a ${space_parallel[@]}) name=memory unit=MB) \
unoptimized=$(jo data=$(jo -a) name=memory unit=MB) \
fitted=$(jo data="`jq '.fitted' ${data_id}.space-parallel-fitted.json`" name=memory unit=MB) \
fit_method="`jq -r '.method' ${data_id}.space-parallel-fitted.json`" \
mse="`jq '.mse' ${data_id}.space-parallel-fitted.json`" \
> $space_parallel_analytics_file_d

# power serial
extn="${power_serial_analytics_file##*.}"
noextn="${power_serial_analytics_file%.*}"

power_serial_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$iva_json" \
measurements=$(jo data=$(jo -a ${power_serial[@]}) name=power unit="watts") \
unoptimized=$(jo data=$(jo -a) name=power unit="watts") \
fitted=$(jo data="`jq '.fitted' ${data_id}.power-serial-fitted.json`" name=power unit="watts") \
fit_method="`jq -r '.method' ${data_id}.power-serial-fitted.json`" \
mse="`jq '.mse' ${data_id}.power-serial-fitted.json`" \
> $power_serial_analytics_file_d

# power parallel
extn="${power_parallel_analytics_file##*.}"
noextn="${power_parallel_analytics_file%.*}"

power_parallel_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$(jo -a "$(jo data="$(jo -a ${core[@]})" name=core unit=count)")" \
measurements=$(jo data=$(jo -a ${power_parallel[@]}) name=power unit="watts") \
fitted=$(jo data="`jq '.fitted' ${data_id}.power-parallel-fitted.json`" name=power unit="watts") \
unoptimized=$(jo data=$(jo -a) name=power unit="watts") \
fit_method="`jq -r '.method' ${data_id}.power-parallel-fitted.json`" \
mse="`jq '.mse' ${data_id}.power-parallel-fitted.json`" \
> $power_parallel_analytics_file_d

# energy serial
extn="${energy_serial_analytics_file##*.}"
noextn="${energy_serial_analytics_file%.*}"

energy_serial_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$iva_json" \
measurements=$(jo data=$(jo -a ${energy_serial[@]}) name=energy unit="watt-seconds") \
unoptimized=$(jo data=$(jo -a) name=energy unit="watt-seconds") \
fitted=$(jo data="`jq '.fitted' ${data_id}.energy-serial-fitted.json`" name=energy unit="watt-seconds") \
fit_method="`jq -r '.method' ${data_id}.energy-serial-fitted.json`" \
mse="`jq '.mse' ${data_id}.energy-serial-fitted.json`" \
> $energy_serial_analytics_file_d

# energy parallel
extn="${energy_parallel_analytics_file##*.}"
noextn="${energy_parallel_analytics_file%.*}"

energy_parallel_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$(jo -a "$(jo data="$(jo -a ${core[@]})" name=core unit=count)")" \
measurements=$(jo data=$(jo -a ${energy_parallel[@]}) name=energy unit="watt-seconds") \
unoptimized=$(jo data=$(jo -a) name=energy unit="watt-seconds") \
fitted=$(jo data="`jq '.fitted' ${data_id}.energy-parallel-fitted.json`" name=energy unit="watt-seconds") \
fit_method="`jq -r '.method' ${data_id}.energy-parallel-fitted.json`" \
mse="`jq '.mse' ${data_id}.energy-parallel-fitted.json`" \
> $energy_parallel_analytics_file_d

# speedup
extn="${speedup_analytics_file##*.}"
noextn="${speedup_analytics_file%.*}"

speedup_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$(jo -a "$(jo data="$(jo -a ${core[@]})" name=core unit=count)")" \
measurements=$(jo data=$(jo -a ${speedup[@]}) name='T1/Tcore' unit='') \
unoptimized=$(jo data=$(jo -a) name='T1/Tcore' unit='') \
fitted=$(jo data="`jq '.fitted' ${data_id}.speedup-fitted.json`" name='T1/Tcore' unit='') \
fit_method="`jq -r '.method' ${data_id}.speedup-fitted.json`" \
mse="`jq '.mse' ${data_id}.speedup-fitted.json`" \
> $speedup_analytics_file_d

# freeup
extn="${freeup_analytics_file##*.}"
noextn="${freeup_analytics_file%.*}"

freeup_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$(jo -a "$(jo data="$(jo -a ${core[@]})" name=core unit=count)")" \
measurements=$(jo data=$(jo -a ${freeup[@]}) name='S1/Score' unit='') \
unoptimized=$(jo data=$(jo -a) name='S1/Score' unit='') \
fitted=$(jo data="`jq '.fitted' ${data_id}.freeup-fitted.json`" name='S1/Score' unit='') \
fit_method="`jq -r '.method' ${data_id}.freeup-fitted.json`" \
mse="`jq '.mse' ${data_id}.freeup-fitted.json`" \
> $freeup_analytics_file_d

# powerup
extn="${powerup_analytics_file##*.}"
noextn="${powerup_analytics_file%.*}"

powerup_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$(jo -a "$(jo data="$(jo -a ${core[@]})" name=core unit=count)")" \
measurements=$(jo data=$(jo -a ${powerup[@]}) name='PowerEfficiency(P1/Pcore)' unit='') \
unoptimized=$(jo data=$(jo -a) name='PowerEfficiency(P1/Pcore)' unit='') \
fitted=$(jo data="`jq '.fitted' ${data_id}.powerup-fitted.json`" name='PowerEfficiency(P1/Pcore)' unit='') \
fit_method="`jq -r '.method' ${data_id}.powerup-fitted.json`" \
mse="`jq '.mse' ${data_id}.powerup-fitted.json`" \
> $powerup_analytics_file_d

# energyup
extn="${energyup_analytics_file##*.}"
noextn="${energyup_analytics_file%.*}"

energyup_analytics_file_d="$noextn"."$extn"

jo -p \
iva="$(jo -a "$(jo data="$(jo -a ${core[@]})" name=core unit=count)")" \
measurements=$(jo data=$(jo -a ${energyup[@]}) name='EnergyEfficiency(E1/Ecore)' unit='') \
unoptimized=$(jo data=$(jo -a) name='EnergyEfficiency(E1/Ecore)' unit='') \
fitted=$(jo data="`jq '.fitted' ${data_id}.energyup-fitted.json`" name='EnergyEfficiency(E1/Ecore)' unit='') \
fit_method="`jq -r '.method' ${data_id}.energyup-fitted.json`" \
mse="`jq '.mse' ${data_id}.energyup-fitted.json`" \
> $energyup_analytics_file_d
