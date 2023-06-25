#!/bin/bash
sql_src_dir="$(dirname $(dirname "$0"))/sql"

sudo docker run -d \
  --name pg_docker \
  -p 5432:5432 \
  --rm \
  -e POSTGRES_PASSWORD=@sde_password012 \
  -e POSTGRES_USER=test_sde \
  -e POSTGRES_DB=demo \
  -v $sql_src_dir:/var/lib/postgresql/sql_data \
  postgres

sleep 5

sudo docker exec pg_docker psql -U test_sde -d demo -f /var/lib/postgresql/sql_data/init_db/demo.sql