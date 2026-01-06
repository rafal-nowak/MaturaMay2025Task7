#!/bin/bash
set -e

INPUT=/data/src/query.sql
EXTRACT=/data/src/active-query.sql
RESULT=/data/src/result.csv
ERRLOG=/data/output/query_error.log

if [[ ! -f "$INPUT" ]]; then
  echo "ERROR: $INPUT not found" >&2
  exit 2
fi

# verify markers existed at all (so student cannot delete them)
if ! grep -q -- "-- $SUBTASK BEGIN" "$INPUT"; then
  echo "ERROR: missing '-- $SUBTASK BEGIN' marker" >&2
  exit 101
fi
if ! grep -q -- "-- $SUBTASK END" "$INPUT"; then
  echo "ERROR: missing '-- $SUBTASK END' marker" >&2
  exit 102
fi

# extract only requested block into $EXTRACT
sed -n "/-- $SUBTASK BEGIN/,/-- $SUBTASK END/p" "$INPUT" \
| sed '1d;$d' \
> "$EXTRACT"

# optional check: empty? (user may have markers but no sql)
if [[ ! -s "$EXTRACT" ]]; then
  echo "ERROR: no SQL between BEGIN/END for $SUBTASK" >&2
  exit 103
fi

# now run ONLY that query
if ! mysql --local-infile=1 \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
      --batch --raw --skip-column-names \
      < "$EXTRACT" > "$RESULT" \
      2> "$ERRLOG"
then
  echo "User query failed. See query_error.log for details."
  exit 100
fi

echo "Subtask $SUBTASK OK."

# Shut down MySQL to allow container to exit
echo "Shutting down MySQL..."
mysqladmin -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" shutdown

exit 0

