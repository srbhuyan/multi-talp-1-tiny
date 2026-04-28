for data_file in data.xCtVR3p7.csv data.GHgs5fsH.csv; do
  data_id="${data_file%.csv}"
  data_id="${data_id#data.}"
  ./analyze.sh main main.c mult r rStart rEnd 2 row 400 \
    $data_file core.txt power-profile.csv \
    ${data_id}.time-serial-analytics.json \
    ${data_id}.time-parallel-analytics.json \
    ${data_id}.time-parallel-slow-analytics.json \
    ${data_id}.space-serial-analytics.json \
    ${data_id}.space-parallel-analytics.json \
    ${data_id}.power-serial-analytics.json \
    ${data_id}.power-parallel-analytics.json \
    ${data_id}.energy-serial-analytics.json \
    ${data_id}.energy-parallel-analytics.json \
    ${data_id}.speedup-analytics.json \
    ${data_id}.freeup-analytics.json \
    ${data_id}.powerup-analytics.json \
    ${data_id}.energyup-analytics.json \
    $1 $2 $3 "$4" $5 $6 $7
done
