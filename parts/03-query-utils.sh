query_tbl() {
	psql <<-EOF
	$1
	EOF
}

query_tsv() {
	psql <<-EOF
	COPY ($1) to STDOUT with CSV DELIMITER E'\t'
	EOF
}

query_csv() {
	psql <<-EOF
	COPY ($1) to STDOUT with CSV DELIMITER ','
	EOF
}

query_exp() {
	psql <<-EOF
	EXPLAIN ANALYZE VERBOSE $1
	EOF
}

query_expj() {
	echo "$1"
	echo
	psql -qAt <<-EOF
	EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) $1
	EOF
}

query_influx() {
	arr2py=$(cat <<EOF
import sys
query_name = sys.argv[1]
fields = {x.split('=')[0]: int(x.split('=')[1]) for x in sys.argv[2].split(';')}
tags = []
if len(sys.argv) > 3 and len(sys.argv[3]) > 0:
	tags = {x.split('=')[0]: int(x.split('=')[1]) for x in sys.argv[3].split(';')}

timestamp = None
if len(sys.argv) > 4 and sys.argv[4] != '':
	timestamp = int(sys.argv[4])

for line in sys.stdin.read().split('\n'):
	if len(line) == 0:
		continue
	parsed = line.split('\t')
	metric = query_name
	if len(tags):
		tag_data = ['%s=%s' % (k, parsed[v].replace(' ', '\\ ').replace(',', '\\,'))  for (k, v) in tags.items()]
		metric += ',' + ','.join(tag_data)
	field_data = ['%s=%s' % (k, parsed[v])  for (k, v) in fields.items()]
	metric += ' ' + ','.join(field_data)

	if timestamp is not None:
		metric += ' ' + str(parsed[timestamp])
	print(metric)
EOF
)

	psql -c "COPY ($1) to STDOUT with CSV DELIMITER E'\t'"| python -c "$arr2py" "$2" "$3" "$4" "$5"
}

elem_in_array() {
	elem_in_arr=$(cat <<EOF
import sys
elem = sys.argv[1]

if elem in sys.argv[2:]:
	sys.exit(0)
else:
	sys.exit(1)
EOF
)

	# remove the first element as that's what we search for
	arr_elems=${@:2}

	# Call Python as it's easier
	python -c "$elem_in_arr" "$1" ${arr_elems[@]}

	# Returnt he correct value for use in if statements
	if [ $? -eq 0 ]; then
		return 0
	else
		return 1
	fi
}

gdpr_safe() {
	local coalesce_to
	if (( $# > 2 )); then
		coalesce_to="$3"
	else
		coalesce_to="__UNKNOWN__"
	fi

	if [ -z "$GDPR_MODE"  ]; then
		echo "COALESCE($1, '$coalesce_to')"
	else
		# Try and be privacy respecting while generating numbers that can allow
		# linking data across tables if need be?
		echo "substring(md5(COALESCE($1, '$coalesce_to') || now()::date), 0, 12) as ${2:-$1}"
	fi
}
