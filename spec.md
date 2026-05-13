# Quarkus CRUD Microservice Specification

## Overview

Transform this project into a **Customer microservice** exposing a RESTful CRUD API backed by a PostgreSQL database. The implementation uses Quarkus with Panache (Active Record pattern), RESTEasy Reactive with Jackson, and Flyway for schema migrations.

This spec is written as a **generic template** -- replace `Customer` with any entity name and adjust the fields to produce any CRUD microservice.

---

## 1. Entity Definition

### Customer

| Field       | Type          | Constraints                          |
|-------------|---------------|--------------------------------------|
| `id`        | `Long`        | Auto-generated primary key           |
| `firstName` | `String`      | Required, max 100 chars              |
| `lastName`  | `String`      | Required, max 100 chars              |
| `email`     | `String`      | Required, unique, valid email format |
| `phone`     | `String`      | Optional, max 20 chars               |
| `createdAt` | `Instant`     | Auto-set on creation, read-only      |
| `updatedAt` | `Instant`     | Auto-set on creation and update      |

---

## 2. API Endpoints

Base path: `/api/v1/customers`

| Method   | Path                    | Description          | Request Body | Success Code |
|----------|-------------------------|----------------------|--------------|--------------|
| `GET`    | `/api/v1/customers`     | List all customers (paginated) | --           | `200`        |
| `GET`    | `/api/v1/customers/{id}`| Get customer by ID   | --           | `200`        |
| `POST`   | `/api/v1/customers`     | Create a customer    | Customer JSON| `201`        |
| `PUT`    | `/api/v1/customers/{id}`| Full update          | Customer JSON| `200`        |
| `DELETE` | `/api/v1/customers/{id}`| Delete a customer    | --           | `204`        |

### Pagination (GET list)

Query parameters: `page` (default `0`), `size` (default `20`).
Response wraps results in an object:

```json
{
  "data": [ ... ],
  "total": 42,
  "page": 0,
  "size": 20
}
```

### Error Responses

All errors return a consistent JSON body:

```json
{
  "error": "Not Found",
  "message": "Customer with id 99 not found",
  "status": 404
}
```

Standard codes: `400` (validation failure), `404` (not found), `409` (duplicate email), `500` (unexpected).

---

## 3. Project Structure

```
src/
  main/
    java/org/redhat/rhdh/
      entity/
        Customer.java            # Panache entity
      resource/
        CustomerResource.java    # JAX-RS endpoints
      dto/
        CustomerRequest.java     # Input DTO (create/update)
        CustomerResponse.java    # Output DTO
        PagedResponse.java       # Generic paginated wrapper
        ErrorResponse.java       # Error body
      mapper/
        CustomerMapper.java      # Entity <-> DTO mapping
      exception/
        NotFoundException.java
        DuplicateEntityException.java
        ExceptionMappers.java    # JAX-RS exception mappers
    resources/
      application.properties
      db/migration/
        V1.0.0__create_customer_table.sql
  test/
    java/org/redhat/rhdh/
      resource/
        CustomerResourceTest.java
```

---

## 4. Technology Stack & Dependencies

Upgrade Quarkus to **3.x** (latest LTS) and move to **Java 17**.

### Maven dependencies to add

| Dependency                              | Purpose                         |
|-----------------------------------------|---------------------------------|
| `quarkus-rest-jackson`                  | RESTEasy Reactive + JSON        |
| `quarkus-hibernate-orm-panache`         | ORM with Active Record pattern  |
| `quarkus-jdbc-postgresql`               | PostgreSQL JDBC driver          |
| `quarkus-flyway`                        | Database schema migrations      |
| `quarkus-hibernate-validator`           | Bean Validation (JSR 380)       |
| `quarkus-smallrye-health`              | Liveness & readiness probes     |
| `quarkus-smallrye-openapi`              | OpenAPI/Swagger (already present)|
| `quarkus-junit5`                        | Testing (already present)       |
| `rest-assured`                          | REST testing (already present)  |
| `quarkus-test-h2` or `quarkus-jdbc-h2` | In-memory DB for tests          |

### Dependencies to remove

| Dependency             | Reason                                  |
|------------------------|-----------------------------------------|
| `quarkus-resteasy`     | Replaced by `quarkus-rest-jackson`      |

---

## 5. Database Migration

File: `src/main/resources/db/migration/V1.0.0__create_customer_table.sql`

```sql
CREATE TABLE customer (
    id         BIGSERIAL    PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name  VARCHAR(100) NOT NULL,
    email      VARCHAR(255) NOT NULL UNIQUE,
    phone      VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_customer_email ON customer (email);
```

---

## 6. Configuration

### application.properties

```properties
# HTTP
quarkus.http.port=8080

# Datasource
quarkus.datasource.db-kind=postgresql
quarkus.datasource.username=${DB_USER:postgres}
quarkus.datasource.password=${DB_PASSWORD:postgres}
quarkus.datasource.jdbc.url=jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:customerdb}
quarkus.datasource.jdbc.max-size=16

# Hibernate
quarkus.hibernate-orm.database.generation=none
quarkus.hibernate-orm.log.sql=false
quarkus.hibernate-orm.physical-naming-strategy=org.hibernate.boot.model.naming.CamelCaseToUnderscoresNamingStrategy

# Flyway
quarkus.flyway.migrate-at-start=true

# OpenAPI
quarkus.smallrye-openapi.info-title=Customer API
quarkus.smallrye-openapi.info-version=1.0.0
quarkus.smallrye-openapi.store-schema-directory=./

# Health
quarkus.health.extensions.enabled=true

# Dev Services (auto-starts PostgreSQL container in dev/test mode)
quarkus.devservices.enabled=true
```

### Test profile (`%test` properties)

```properties
%test.quarkus.datasource.db-kind=h2
%test.quarkus.datasource.jdbc.url=jdbc:h2:mem:testdb;MODE=PostgreSQL
%test.quarkus.hibernate-orm.database.generation=drop-and-create
%test.quarkus.flyway.migrate-at-start=false
```

---

## 7. Implementation Details

### 7.1 Entity (Active Record with Panache)

- Extend `PanacheEntity` (auto `id` field).
- Use `@Table(name = "customer")` and map fields with `@Column`.
- Use `@PrePersist` / `@PreUpdate` callbacks for `createdAt` / `updatedAt`.
- Add a finder method: `findByEmail(String email)`.

### 7.2 DTOs

**CustomerRequest** -- used for both `POST` and `PUT`:
- `firstName` (`@NotBlank`, `@Size(max=100)`)
- `lastName` (`@NotBlank`, `@Size(max=100)`)
- `email` (`@NotBlank`, `@Email`)
- `phone` (`@Size(max=20)`)

**CustomerResponse** -- returned from endpoints:
- All entity fields including `id`, `createdAt`, `updatedAt`.

**PagedResponse<T>** -- generic paginated wrapper:
- `List<T> data`, `long total`, `int page`, `int size`.

### 7.3 Resource (JAX-RS)

- Annotate class with `@Path("/api/v1/customers")`, `@Produces(APPLICATION_JSON)`, `@Consumes(APPLICATION_JSON)`.
- Inject `Validator` for manual validation where needed.
- All mutating operations are `@Transactional`.
- Return `Response` objects with correct status codes and `Location` header on `POST`.
- Use `@Valid` on request body parameters.

### 7.4 Exception Mappers

Register JAX-RS `ExceptionMapper` implementations for:
- `NotFoundException` -> 404
- `DuplicateEntityException` -> 409
- `ConstraintViolationException` -> 400 (list individual field errors)

### 7.5 Mapper

A simple static utility class (no MapStruct dependency) with:
- `toEntity(CustomerRequest dto)` -> `Customer`
- `toResponse(Customer entity)` -> `CustomerResponse`

---

## 8. Dockerfile Updates

Update the Dockerfile to use **Java 17** base image:

```dockerfile
FROM registry.access.redhat.com/ubi8/openjdk-17:1.18
```

---

## 9. Testing

### Unit / Integration Tests (`CustomerResourceTest`)

Test each endpoint:

| Test Case                        | Method  | Expected |
|----------------------------------|---------|----------|
| Create valid customer            | POST    | 201, body matches, Location header set |
| Create with missing fields       | POST    | 400, error body with field details     |
| Create with duplicate email      | POST    | 409                                    |
| Get existing customer            | GET     | 200, correct body                      |
| Get non-existent customer        | GET     | 404                                    |
| List customers (pagination)      | GET     | 200, paged response format             |
| Update existing customer         | PUT     | 200, updated fields reflected          |
| Update non-existent customer     | PUT     | 404                                    |
| Delete existing customer         | DELETE  | 204                                    |
| Delete non-existent customer     | DELETE  | 404                                    |

Use `@QuarkusTest` with the H2 test profile.

---

## 10. Dev Workflow

```bash
# Start in dev mode (auto-starts PostgreSQL via Dev Services)
./mvnw quarkus:dev

# Run tests
./mvnw test

# Build for production
./mvnw package

# Build container image
docker build -f Dockerfile -t customer-api .

# Run with external PostgreSQL
docker run -p 8080:8080 \
  -e DB_HOST=db -e DB_PORT=5432 \
  -e DB_NAME=customerdb \
  -e DB_USER=postgres -e DB_PASSWORD=postgres \
  customer-api
```

---

## 11. Files to Modify

| File                       | Action  | Description                                  |
|----------------------------|---------|----------------------------------------------|
| `pom.xml`                  | Modify  | Upgrade Quarkus 3.x, Java 17, add/remove deps|
| `application.properties`   | Modify  | Add datasource, Flyway, health config        |
| `ExampleResource.java`     | Delete  | Replaced by CustomerResource                 |
| `ExampleResourceTest.java` | Delete  | Replaced by CustomerResourceTest             |
| `ExampleResourceIT.java`   | Delete  | No longer needed                             |
| `Dockerfile`               | Modify  | Update base image to Java 17                 |
| `openapi.yaml`             | Regenerate | Auto-generated from annotations            |
| All files in Section 3     | Create  | Entity, resource, DTOs, mapper, exceptions, migration, tests |

---

## 12. Making This a Generic Template

To reuse this spec for a different entity:

1. **Replace the entity name**: `Customer` -> `Product`, `Order`, etc.
2. **Replace the fields** in Section 1 with the new entity's fields.
3. **Update the base path** in Section 2: `/api/v1/customers` -> `/api/v1/products`.
4. **Update the migration SQL** in Section 5 with the new table/columns.
5. **Rename files** accordingly: `CustomerResource` -> `ProductResource`, etc.

Everything else (project structure, configuration pattern, pagination, error handling, test matrix) stays the same.
