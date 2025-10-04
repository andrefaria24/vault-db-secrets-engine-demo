# Vault Database Secrets Engine Demo

A compact demo that shows how HashiCorp Vault's Database Secrets Engine can manage both static and dynamic credentials
for Microsoft SQL Server and PostgreSQL.

The repo includes a Docker Compose file for local databases and a sample
`setup.sql` script to initialize the SQL Server databases and logins.

## Table of Contents
- Prerequisites
- Quick start (recommended)
- Manual Vault configuration examples (static & dynamic roles)
- Cleanup

---

## Prerequisites
- Docker (to run database containers)
- HashiCorp Vault CLI (tested with Vault v1.20.x)
- `psql` client for PostgreSQL testing
- `sqlcmd` client for running T-SQL scripts against SQL Server
- (Optional) SQL Server Management Studio for interactive inspection
- PowerShell 7.x is recommended for wrapper scripts in this repo (or adapt the commands for your shell)

---

## Quick start (recommended)
These steps get the demo running locally with minimal friction. They assume you will provide secrets at runtime instead
of checking them into the repository.

1. Clone the repository and change into it:

```powershell
git clone <repo-url>
cd vault-db-secrets-engine-demo
```

2. Start the database containers (this repo's `docker-compose.yml` will bring up SQL Server and PostgreSQL):

```powershell
docker compose up -d
```

3. Initialize the SQL Server objects securely.

- Option A (recommended): use a local wrapper script that reads passwords from environment variables and calls `sqlcmd`.
  Example pattern (PowerShell):

```powershell
$vaultLoginPwd = Read-Host 'Vault login password' -AsSecureString
$vaultStaticPwd = Read-Host 'Vault static password' -AsSecureString

$loginPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($vaultLoginPwd))
$staticPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($vaultStaticPwd))

sqlcmd -S . -i setup.sql -v VaultLoginPassword="$loginPlain" VaultStaticPassword="$staticPlain"
```

- Option B: open `setup.sql` in SSMS (Query > SQLCMD Mode) and supply variables with `:setvar` before running.

4. Start a Vault dev server for testing:

```powershell
vault server -dev
```

5. Configure Vault environment variables for the CLI:

```powershell
$env:VAULT_ADDR = 'http://127.0.0.1:8200'
$env:VAULT_TOKEN = '<ROOT_TOKEN_FROM_DEV_SERVER>'
```

6. Enable the database secrets engine:

```powershell
vault secrets enable database
```

---

## Manual Vault configuration examples
Replace placeholders like `<YOUR_PASSWORD>` with secure values provided at runtime.

### MSSQL — Static credentials
Configure the database connection in Vault (static credentials example):

```powershell
vault write database/config/mssql_static \
  plugin_name=mssql-database-plugin \
  connection_url='sqlserver://{{username}}:{{password}}@localhost:1433' \
  allowed_roles="mssql_static" \
  username="vault_login" \
  password="<YOUR_PASSWORD>"
```

Create a static role mapping (long rotation period used in demo to emulate static creds):

```powershell
vault write database/static-roles/mssql_static \
  db_name=mssql_static \
  username="vault_static" \
  rotation_statements="ALTER LOGIN [{{name}}] WITH PASSWORD = '{{password}}';" \
  rotation_period="876000h"
```

Read the credential (returns username/password):

```powershell
vault read database/static-creds/mssql_static
```

### MSSQL — Dynamic credentials
Configure connection (use a user with privilege to create logins/users):

```powershell
vault write database/config/mssql_dynamic \
  plugin_name=mssql-database-plugin \
  connection_url='sqlserver://{{username}}:{{password}}@localhost:1433' \
  allowed_roles="mssql_dynamic" \
  username="vault_login" \
  password="<YOUR_PASSWORD>"
```

Role that creates a temporary login and user with SELECT privileges:

```powershell
vault write database/roles/mssql_dynamic \
  db_name=mssql_dynamic \
  creation_statements="CREATE LOGIN [{{name}}] WITH PASSWORD = '{{password}}'; USE [test_db_2]; CREATE USER [{{name}}] FOR LOGIN [{{name}}]; GRANT SELECT ON SCHEMA::dbo TO [{{name}}];" \
  revocation_statements="DROP USER IF EXISTS [{{name}}]; DROP LOGIN IF EXISTS [{{name}}];" \
  default_ttl="1h" \
  max_ttl="24h"
```

Generate dynamic credentials:

```powershell
vault read database/creds/mssql_dynamic
```

### PostgreSQL — Dynamic credentials
Configure connection to PostgreSQL (use a privileged account):

```powershell
vault write database/config/postgresql_dynamic \
  plugin_name="postgresql-database-plugin" \
  allowed_roles="postgresql_dynamic" \
  connection_url="postgresql://{{username}}:{{password}}@localhost:5432/test_db_1" \
  username="vault_user" \
  password="<YOUR_PASSWORD>" \
  password_authentication="scram-sha-256"
```

Role that creates a temporary PostgreSQL role with SELECT privileges:

```powershell
vault write database/roles/postgresql_dynamic \
  db_name="postgresql_dynamic" \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

Generate a credential and connect using `psql`:

```powershell
$creds = vault read -format=json database/creds/postgresql_dynamic | ConvertFrom-Json
psql -h localhost -p 5432 -U $creds.data.username -d test_db_1
```

---

## Cleanup
- Stop and remove containers:

```powershell
docker compose down -v
```

- Remove any generated logins/users you created during the demo (use SSMS or `sqlcmd` to run cleanup statements).