# Sowfkun Verse API Integration Guide

Welcome to the **Sowfkun Verse API Integration Guide**. This document is designed for AI Integrators (Frontend Agents) and Human Developers.

## Folder Structure

This directory contains flows for integrating with the Sowfkun Verse API:

1. [Handshake & Security Flow](./SECURITY_FLOW.md)
   - How to establish End-to-End Encryption (E2EE) with the backend.
2. [Authentication & Onboarding Flow](./AUTH_FLOW.md)
   - How to register and authenticate users.
3. [Tenant Management Flow](./TENANT_FLOW.md)
   - How to manage tenant information.

## Global Conventions

- **Base URL:** `http://localhost:8080/api/v1`
- **Content-Type:** `application/json`
- **JWT Auth:** Most endpoints require `Authorization: Bearer <token>`
- **Response Format:**
  ```json
  {
    "code": "MSG_SUCCESS",
    "message": "Localized message",
    "data": { ... }
  }
  ```
