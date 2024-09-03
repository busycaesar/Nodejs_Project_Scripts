#!/bin/bash

data_volume=$1

if [ -z "$data_volume" ]; then
    echo "The name of the volume is not provided."
    exit 1
fi

# Install all the dependencies.
echo "Install all the required dependencies."
npm install pg || (echo "Error while installing the dependencies." && exit 1)

# Create all the required directories and files.
echo "Creating the required project structure."
mkdir -p src/db docker &&
touch postgres.env docker-compose.yml src/db/db.js src/db/index.js postgres.env src/db/table.sql src/db/table.js || (echo "Error while creating the project structure." && exit 1)

echo "Adding content into the files."

cat <<EOL > docker-compose.yml
services:
  db:
    image: postgres:13
    restart: always
    env_file:
      - postgres.env
    ports:
      - "5432:5432"
    volumes:
      - $data_volume:/var/lib/postgresql/data

volumes:
  $data_volume:
EOL

cat <<EOL > postgres.env
# For postgres image
POSTGRES_USER=${data_volume}_user
POSTGRES_PASSWORD=${data_volume}_passwd
POSTGRES_DB=${data_volume}_db

# For application to connect with postgres image
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
EOL

cat <<EOL > src/db/db.js
const { Pool } = require("pg");
const path = require("path");
require("dotenv").config();
require("dotenv").config({
  path: path.resolve(__dirname, "../../postgres.env"),
});

if (
  !process.env.POSTGRES_USER ||
  !process.env.POSTGRES_PASSWORD ||
  !process.env.POSTGRES_DB ||
  !process.env.POSTGRES_HOST ||
  !process.env.POSTGRES_PORT
) {
  console.log("Postgres credentials not provided.");
  process.exit(1);
}

console.log(
  process.env.POSTGRES_USER,
  process.env.POSTGRES_HOST,
  process.env.POSTGRES_DB,
  process.env.POSTGRES_PASSWORD,
  process.env.POSTGRES_PORT
);

const pool = new Pool({
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  host: process.env.POSTGRES_HOST,
  port: process.env.POSTGRES_PORT,
});

module.exports = pool;
EOL

cat <<EOL > src/db/table.js
const pool = require("./db");
const fs = require("fs");

const createTables = () => {
  return new Promise((resolve, reject) => {
    const createTableQuery = fs.readFileSync("src/db/table.sql", "utf8");

    pool
      .query(createTableQuery)
      .then(() => {
        console.log("All tables created.");
        resolve();
      })
      .catch((error) =>
        reject(
          new Error(
            \`Database error while creating all the tables. \${error.message}\`
          )
        )
      );
  });
};

const dbHealthCheck = () => {
  return new Promise((resolve, reject) => {
    const healthCheckQuery = \`SELECT CURRENT_TIMESTAMP as health_check_time;\`;
    pool
      .query(healthCheckQuery)
      .then((result) => resolve(result.rows[0].health_check_time))
      .catch((error) =>
        reject(new Error(\`Database error while health check. \${error}\`))
      );
  });
};

module.exports = { createTables, dbHealthCheck };
EOL

cat <<EOL > src/db/index.js
const { createTables, dbHealthCheck } = require("./table");

module.exports = { createTables, dbHealthCheck };
EOL