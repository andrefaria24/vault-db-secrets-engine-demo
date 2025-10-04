# Vault Database Secrets Engine Demo

This repo will create the necessary components to demonstrate HashiCorp Vault Database Secrets Engine capabiltiies for Microsoft SQL Server and PostgreSQL. It showcases both static and dynamic secrets.

All these commands were built and tested on PowerShell v7.5.3. Please remember to change syntax depending on the shell/terminal used.

## Demo Prerequisites

- Docker installed and running on your local machine.
- HashiCorp Vault CLI installed (This demo was last executed with Vault v1.20.4).
- PostgreSQL and SQL Server images available for Docker.
- Access to a shell/terminal.
- `psql` client installed for PostgreSQL access.
- Microsoft SQL Server Management Studio installed on your local machine to showcase how the database secrets engine works under the hood within MSSQL.

## Demo Setup

1. Clone this repository and change into it's directory:

    ```powershell
    git clone <repo-url>
    cd vault-db-secrets-engine-demo
    ```
    
2. Start the database containers:

    ```powershell
    docker compose up -d
    ```

3. Initialize databases:
    - Use SSMS to connect to the running SQL Server instance and execute `setup.sql`.

4. Start Vault in dev mode:

    ```powershell
    vault server -dev
    ```

5. Set environment variables for Vault:

    ```powershell
    export VAULT_ADDR='http://127.0.0.1:8200'
    export VAULT_TOKEN='<YOUR TOKEN VALUE>'
    ```

6. Enable the database secrets engine:

    ```powershell
    vault secrets enable database
    ```

### MSSQL Static Credentials Demonstration

1. Configure Vault with the proper plugin and connection information:

    ```powershell
    vault write database/config/mssql_static `
        plugin_name=mssql-database-plugin `
        connection_url='sqlserver://{{username}}:{{password}}@localhost:1433' `
        allowed_roles="mssql_static" `
        username="vault_login" `
        password="<YOUR_PASSWORD>"
    ```

2. Configure a role that maps a name in Vault to an SQL statement to execute to create the database credential:

    ```powershell
    vault write database/static-roles/mssql_static `
        db_name=mssql_static `
        username="vault_static" `
        rotation_statements="ALTER LOGIN [{{name}}] WITH PASSWORD = '{{password}}';" `
        rotation_period="876000h"
    ```

3. Generate a new credential by reading from the /creds endpoint with the name of the role:

    ```powershell
    vault read database/static-creds/mssql_static
    ```

### MSSQL Dynamic Credentials Demonstration

1. Configure Vault with the proper plugin and connection information:

    ```powershell
    vault write database/config/mssql_dynamic `
        plugin_name=mssql-database-plugin `
        connection_url='sqlserver://{{username}}:{{password}}@localhost:1433' `
        allowed_roles="mssql_dynamic" `
        username="vault_login" `
        password="<YOUR_PASSWORD>"
    ```

2. Configure a role that maps a name in Vault to an SQL statement to execute to create the database credential:

    ```powershell
    vault write database/roles/mssql_dynamic `
        db_name=mssql_dynamic `
        creation_statements="CREATE LOGIN [{{name}}] WITH PASSWORD = '{{password}}'; USE [test_db_2]; CREATE USER [{{name}}] FOR LOGIN [{{name}}]; GRANT SELECT ON SCHEMA::dbo TO [{{name}}];" `
        revocation_statements="DROP USER IF EXISTS [{{name}}];" `
        default_ttl="1h" `
        max_ttl="24h"
    ```

3. Generate a new credential by reading from the /creds endpoint with the name of the role:

    ```powershell
    vault read database/creds/mssql_dynamic
    ```

### PostgreSQL Dynamic Credentials Demonstration

1. Configure Vault with the proper plugin and connection information:

    ```powershell
    vault write database/config/postgresql_dynamic `
        plugin_name="postgresql-database-plugin" `
        allowed_roles="postgresql_dynamic" `
        connection_url="postgresql://{{username}}:{{password}}@localhost:5432/test_db_1" `
        username="vault_user" `
        password="<YOUR_PASSWORD>" `
        password_authentication="scram-sha-256"
    ```

2. Configure a role that maps a name in Vault to an SQL statement to execute to create the database credential:

    ```powershell
    vault write database/roles/postgresql_dynamic `
        db_name="postgresql_dynamic" `
        creation_statements="CREATE ROLE ""{{name}}"" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO ""{{name}}"";" `
        default_ttl="1h" `
        max_ttl="24h"
    ```

3. Generate a new credential by reading from the /creds endpoint with the name of the role:

    ```powershell
    vault read database/creds/postgresql_dynamic
    ```

4. Connect to the PostgreSQL database using the psql command and generated credentials:

    ```powershell
    psql -h localhost -p 5432 -U <generated-username> -d test_db_1
    ```