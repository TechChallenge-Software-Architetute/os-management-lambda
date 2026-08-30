# os-management-lambda

Serverless **CPF authentication** for the os-management platform (FIAP SOAT — Tech Challenge Fase 3).

This repository contains the AWS Lambda functions and the Terraform/CI‑CD needed to:

1. **Issue tokens** — validate a client's CPF, confirm the client exists and is **active** in the database, and return a signed **JWT**.
2. **Authorize requests** — validate that JWT on protected API Gateway routes before traffic reaches the backend.

---

## Responsibilities (two functions, one contract)

| Function | Handler | Role |
|---|---|---|
| **Auth issuer** | `com.os.workshop.auth.AuthHandler` | `POST /auth` — validates CPF, checks client status in the DB, **issues** a JWT. Runs in the VPC to reach the database. |
| **Token authorizer** | `com.os.workshop.auth.TokenAuthorizerHandler` | API Gateway `TOKEN` authorizer — **validates** the JWT on protected routes. No DB access. |

Both sign/verify with the **same shared `JWT_SECRET`** (HS256), so tokens issued here are verifiable across the platform.

> The issuer only *issues*; the authorizer only *validates*. A client authenticates once at `/auth`, then sends `Authorization: Bearer <token>` on every protected call.

---

## Technologies

- **Java 21**, Maven (fat jar via `maven-shade-plugin`)
- **jjwt 0.13.0** (HS256) — same library/version as the main app
- **PostgreSQL JDBC** — lookup on `clients.document`
- **AWS Lambda + API Gateway (REST)** — provisioned with **Terraform**
- **AWS Secrets Manager** — managed store for `JWT_SECRET` and DB credentials
- **GitHub Actions** — CI (test + `terraform validate`) and CD (`develop`→homolog, `main`→prod)

---

## Architecture

```mermaid
flowchart LR
    client([Client])
    subgraph AWS
      apigw[API Gateway REST]
      issuer[Lambda: Auth Issuer]
      authz[Lambda: Token Authorizer]
      sm[(Secrets Manager)]
      db[(PostgreSQL - clients)]
      backend[Backend API on Kubernetes]
    end

    client -- "POST /auth {cpf}" --> apigw
    apigw -- AWS_PROXY --> issuer
    issuer -- "SELECT by document" --> db
    issuer -- "signed JWT" --> client

    client -- "ANY /* (Bearer JWT)" --> apigw
    apigw -- "validate token" --> authz
    authz -- "Allow / Deny" --> apigw
    apigw -- "HTTP_PROXY (if allowed)" --> backend

    issuer -. reads .-> sm
    authz -. reads .-> sm
```

### Authentication sequence

```mermaid
sequenceDiagram
    participant C as Client
    participant G as API Gateway
    participant I as Auth Issuer (Lambda)
    participant D as PostgreSQL
    participant Z as Authorizer (Lambda)
    participant B as Backend API

    C->>G: POST /auth { cpf }
    G->>I: proxy event
    I->>I: validate CPF (check digits)
    I->>D: SELECT id,name,active WHERE document = cpf
    alt not found
        I-->>C: 404 Client not found
    else inactive
        I-->>C: 403 Client is inactive
    else valid & active
        I-->>C: 200 { token, expiresIn, client }
    end

    C->>G: GET /orders (Authorization: Bearer <token>)
    G->>Z: TOKEN authorizer
    Z->>Z: verify signature + expiration
    alt valid
        Z-->>G: Allow (principal = CPF)
        G->>B: forward request
        B-->>C: 200 protected response
    else invalid/expired
        Z-->>G: 401 Unauthorized
        G-->>C: 401
    end
```

---

## API

### `POST /auth`

Request:

```json
{ "cpf": "529.982.247-25" }
```

CPF is accepted formatted or as raw digits.

Responses:

| Status | Body | Meaning |
|---|---|---|
| `200` | `{ "token": "...", "expiresIn": 86400000, "client": { "id": 1, "name": "JOAO DA SILVA" } }` | Authenticated |
| `400` | `{ "error": "Invalid CPF" }` / `{ "error": "CPF is required" }` | Bad/missing CPF |
| `404` | `{ "error": "Client not found" }` | No client with that document |
| `403` | `{ "error": "Client is inactive" }` | Client exists but is deactivated |

The JWT payload:

```json
{
  "sub": "52998224725",
  "clientId": 1,
  "name": "JOAO DA SILVA",
  "roles": ["CLIENT"],
  "iat": 1690000000,
  "exp": 1690086400
}
```

### Postman / Bruno

The platform API collection lives in the main `os-management` repo under `bruno/os-management-api` (`01 - Auth`). Point the `baseUrl` environment variable at the API Gateway stage URL from the Terraform `auth_endpoint` output.

---

## Build & test locally

```bash
./mvnw clean verify        # compile + run unit tests
./mvnw package             # build the Lambda fat jar (target/os-management-lambda.jar)
```

## Deploy (Terraform)

Prerequisites: an S3 bucket for remote state, a VPC with subnets/security groups that can reach the database, and the backend URL.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in real values (never commit)

terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="key=lambda/homolog/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform apply
```

Key outputs: `auth_endpoint`, `api_base_url`.

### Environment variables consumed by the functions

| Variable | Function | Purpose |
|---|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | issuer | database connection |
| `JWT_SECRET` | issuer + authorizer | HS256 sign/verify (shared) |
| `JWT_EXPIRATION` | issuer | token lifetime (ms, default 86400000) |

---

## CI/CD

- **Branch protection:** `main` (prod) and `develop` (homolog) — no direct commits; merges via Pull Request.
- **CI** (`.github/workflows/ci.yml`): on PRs to `develop`/`main` and on `feature/**` pushes — runs Java tests and `terraform fmt`/`validate`.
- **CD** (`.github/workflows/cd.yml`): on push to `develop` → **homolog**, on push to `main` → **prod** — packages the jar and runs `terraform apply` against the matching environment.

Required GitHub secrets (per environment): `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `TF_STATE_BUCKET`, `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`, `VPC_SUBNET_IDS`, `VPC_SECURITY_GROUP_IDS`, `PROTECTED_BACKEND_URL`.

> `VPC_SUBNET_IDS` and `VPC_SECURITY_GROUP_IDS` are Terraform lists — store them as JSON, e.g. `["subnet-a","subnet-b"]`.

---

## Notes

- Remember to add the **`soat-architecture`** user to this repository (Tech Challenge delivery requirement).
- Secrets are managed in AWS Secrets Manager and injected as Lambda environment variables so the function code stays runtime-agnostic; fetching them at runtime via the AWS SDK is a straightforward future hardening.
