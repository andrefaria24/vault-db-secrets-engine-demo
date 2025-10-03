# Vault Database Dynamic Secrets Demo

## Demo Prerequisites

- Docker installed and running
- HashiCorp Vault CLI installed
- PostgreSQL and SQL Server images available for Docker
- Access to a shell/terminal
- `psql` client installed for PostgreSQL access

## Demo Setup

1. Clone this repository:
    ```sh
    git clone <repo-url>
    cd vault-db-secrets-engine-demo
    ```
2. Start the database containers:
    ```sh
    docker compose up -d
    ```
3. Initialize databases:
    - Execute `setup.sql` against the running SQL Server instance.
4. Start Vault in dev mode:
    ```sh
    vault server -dev
    ```
5. Set environment variables for Vault:
    ```sh
    export VAULT_ADDR='http://127.0.0.1:8200'
    export VAULT_TOKEN='<YOUR TOKEN VALUE>'
    ```
6. Enable the database secrets engine:
    ```sh
    vault secrets enable database
    ```

### MSSQL Static Credentials

```sh
vault write database/config/mssql_static `
    plugin_name=mssql-database-plugin `
    connection_url='sqlserver://{{username}}:{{password}}@localhost:1433' `
    allowed_roles="mssql_static" `
    username="vault_login" `
    password="l1ghtsp33d#"

vault write database/static-roles/mssql_static `
    db_name=mssql_static `
    username="vault_static" `
    rotation_statements="ALTER LOGIN [{{name}}] WITH PASSWORD = '{{password}}';" `
    rotation_period="876000h"

vault read database/static-creds/mssql_static
```

### MSSQL Dynamic Credentials

```sh
vault write database/config/mssql_dynamic `
    plugin_name=mssql-database-plugin `
    connection_url='sqlserver://{{username}}:{{password}}@localhost:1433' `
    allowed_roles="mssql_dynamic" `
    username="vault_login" `
    password="l1ghtsp33d#"

vault write database/roles/mssql_dynamic `
    db_name=mssql_dynamic `
    creation_statements="CREATE LOGIN [{{name}}] WITH PASSWORD = '{{password}}'; USE [test_db_2]; CREATE USER [{{name}}] FOR LOGIN [{{name}}]; GRANT SELECT ON SCHEMA::dbo TO [{{name}}];" `
    revocation_statements="DROP USER IF EXISTS [{{name}}];" `
    default_ttl="1h" `
    max_ttl="24h"

vault read database/creds/mssql_dynamic
```

### PostgreSQL Dynamic Credentials

```sh
vault write database/config/postgresql_dynamic `
    plugin_name="postgresql-database-plugin" `
    allowed_roles="postgresql_dynamic" `
    connection_url="postgresql://{{username}}:{{password}}@localhost:5432/test_db_1" `
    username="vault_user" `
    password="l1ghtsp33d#" `
    password_authentication="scram-sha-256"

vault write database/roles/postgresql_dynamic `
    db_name="postgresql_dynamic" `
    creation_statements="CREATE ROLE ""{{name}}"" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO ""{{name}}"";" `
    default_ttl="1h" `
    max_ttl="24h"

vault read database/creds/postgresql_dynamic

psql -h localhost -p 5432 -U <generated-username> -d test_db_1
```