#!/bin/sh

solr_url="http://localhost:8983/solr/my_config"  # hard-coded
jar="warc-indexer-3.2.0-SNAPSHOT-jar-with-dependencies.jar"

for f in "$@"; do
  echo "processing file $file..."
  #java -Xmx1024M -Djava.io.tmpdir=tika_tmp -jar "$jar" -c config3.conf -s "$solr_url" "$f"
done
