# Disable Vendor Write APIs Implementation Plan

> **For agentic workers:** Implement this plan task by task.

**Goal:** Stop merchant-side Vendor onboarding writes while preserving Admin workflows and non-Vendor charging.

**Architecture:** Comment out the three Vendor submission resolver methods so Nest removes those operations from the GraphQL schema, and remove them from the checked-in schema snapshot. Reject only `type=Vendor` on the `payAccountCharging` GraphQL path before it calls the shared service, leaving the Admin update path untouched.

**Tech Stack:** NestJS, TypeScript, GraphQL, TypeORM.

**Spec:** `docs/superpowers/specs/2026-10-29-disable-vendor-write-apis-design.md`

## Global Constraints

- Remove `createVendor`, `resubmitVendor`, and `updateVendor` from GraphQL.
- Reject `payAccountCharging` only when `type` is `Vendor`.
- Keep `GlobalAccount` and `InternationalEdition` charging behavior unchanged.
- Keep Admin queries, assignment, and review operations unchanged.
- Do not create an exception for order 317764.

## Review Focus

- Missing/default charging type must continue through existing non-Vendor behavior.
- Admin `updateAccountCharging` must remain unaffected despite sharing its service method.
- The three retired Vendor write fields must be absent from the checked-in GraphQL schema snapshot.
- Existing Admin read and approval resolver methods must remain unchanged.

---

### Task 1: Remove Vendor onboarding submission fields

**Files:**
- Modify: `src/modules/vendor/vendor.resolver.ts`
- Modify: `graphql/test-graphql-api.graphql`

- [ ] Comment out `createVendor`, `resubmitVendor`, and `updateVendor` resolver methods.
- [ ] Remove the three corresponding fields and descriptions from the GraphQL schema snapshot.
- [ ] Leave service implementations intact for internal maintenance.

### Task 2: Close only Vendor account charging

**Files:**
- Modify: `src/modules/account-charging/account-charging.resolver.ts`

- [ ] In `payAccountCharging`, reject `params.type === AccountChargingTypeEnum.Vendor` before calling `updateAccountCharging`.
- [ ] Keep `GlobalAccount`, `InternationalEdition`, omitted type/default behavior, and the Admin-only `updateAccountCharging` resolver unchanged.

### Completion review

- [ ] Inspect the diff to confirm the three GraphQL fields are removed, Vendor payment is rejected at the pay resolver, and Admin paths remain unchanged.
