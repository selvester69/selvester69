#!/bin/bash

# A script to create a new PostgreSQL server instance.
#
# This script initializes a new database cluster, creates a superuser named 'root'
# with a password of 'root', and creates a configurable default database.
#
# Usage:
#   ./create_postgres_server.sh [data_directory] [port] [database_name]
#
# Example:
#   ./create_postgres_server.sh /Users/myuser/postgres_data 5434 my_app_db

# Exit the script immediately if any command fails.
set -e

# --- 1. Define and Validate Parameters ---

# Define default values for optional parameters
DEFAULT_DIR="/tmp/postgres_data"
DEFAULT_PORT="5433"
DEFAULT_DB="postgres"

# Assign command line arguments to variables, using defaults if not provided.
DATA_DIR="${1:-$DEFAULT_DIR}"
PORT="${2:-$DEFAULT_PORT}"
DB_NAME="${3:-$DEFAULT_DB}"

# Check for required commands.
if ! command -v initdb &> /dev/null || ! command -v pg_ctl &> /dev/null || ! command -v psql &> /dev/null
then
    echo "Error: Required PostgreSQL commands (initdb, pg_ctl, psql) could not be found."
    echo "Please ensure PostgreSQL is installed and its bin directory is in your system's PATH."
    exit 1
fi

# --- 2. Initialize and Configure the Database Cluster ---

echo "Initializing new PostgreSQL data directory at: $DATA_DIR"
# Check if the data directory already exists.
if [ -d "$DATA_DIR" ]; then
    echo "Warning: Data directory already exists. Skipping initialization."
else
    # Initialize the new database cluster.
    initdb -D "$DATA_DIR"
fi

echo "Setting authentication method to allow password-based login..."
# Update the pg_hba.conf file to allow password authentication for local connections.
# This ensures we can log in with the new 'root' user.
sed -i.bak 's/^\(host.*127\.0\.0\.1\/32\).*peer$/\1md5/' "$DATA_DIR/pg_hba.conf"
sed -i.bak 's/^\(host.*::1\/128\).*peer$/\1md5/' "$DATA_DIR/pg_hba.conf"

# --- 3. Start the Server ---

echo "Starting PostgreSQL server on port: $PORT"
# Start the server in the background, specifying the data directory and port.
pg_ctl -D "$DATA_DIR" -o "-p $PORT" -l "$DATA_DIR/logfile" start

# Wait for the server to be ready before trying to connect.
sleep 3

# --- 4. Create Superuser and Database ---

echo "Creating 'root' superuser and '$DB_NAME' database..."
# Use a here-document to pass multiple SQL commands to psql.
# We connect as the default 'postgres' superuser to perform these actions.
psql -U postgres -d postgres -p "$PORT" -h localhost <<-EOF
    -- Create the 'root' user with superuser privileges and password 'root'.
    CREATE USER root WITH SUPERUSER PASSWORD 'root';
    -- Create the specified database and grant all privileges to the 'root' user.
    CREATE DATABASE "$DB_NAME" OWNER root;
EOF

# --- 5. Verify and Conclude ---

echo "PostgreSQL server setup complete."
echo "You can now connect as the 'root' user with the following command:"
echo "psql -U root -d $DB_NAME -p $PORT -h localhost"
